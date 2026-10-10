import {NextRequest} from "next/server";
import {getToken,decode} from "next-auth/jwt";
import {db} from "./db";
import {createHash} from "node:crypto";
export type Context={token:string;repo:string;subject:string;kind:"admin"|"user"|"device";deviceId?:string};
export class ApiError extends Error {constructor(public status:number,message:string){super(message)}}
export const hash=(s:string)=>createHash("sha256").update(s).digest("hex");
export const reply=(data:unknown,status=200)=>Response.json(data,{status,headers:{"Cache-Control":"private, no-store"}});
export function origin(req:NextRequest){if(req.headers.get("origin")!=="https://rdpfree.projectkal.my.id")throw new ApiError(403,"Origin tidak diizinkan");}
export async function body(req:NextRequest){const raw=await req.text();if(raw.length>16384)throw new ApiError(413,"Payload terlalu besar");try{const d=JSON.parse(raw);if(!d||typeof d!=="object"||Array.isArray(d))throw Error();return d as Record<string,unknown>;}catch{throw new ApiError(400,"JSON tidak valid")}}
async function selected(subject:string,fallback:string){const r=await db().prepare("SELECT repo FROM repositories WHERE subject=?").bind(subject).first<{repo:string}>();return r?.repo||fallback;}
export async function context(req:NextRequest,browserOnly=false):Promise<Context>{
 const authorization=req.headers.get("authorization");
 if(authorization){
  if(browserOnly)throw new ApiError(403,"Gunakan sesi browser untuk pengaturan perangkat");
  const match=/^Bearer (rdf_[A-Za-z0-9_-]{43})$/.exec(authorization);if(!match)throw new ApiError(401,"Token perangkat tidak valid");
  const row=await db().prepare("SELECT id,payload,subject,expires FROM devices WHERE token_hash=?").bind(hash(match[1])).first<{id:string;payload:string;subject:string;expires:number}>();
  if(!row||row.expires<Date.now())throw new ApiError(401,"Token perangkat kedaluwarsa atau dicabut");
  const d=await decode({token:row.payload,secret:process.env.NEXTAUTH_SECRET!});
  if(!d||typeof d.accessToken!=="string"||typeof d.repo!=="string")throw new ApiError(401,"Sesi perangkat tidak valid");
  return {token:d.accessToken,repo:d.repo,subject:row.subject,kind:"device",deviceId:row.id};
 }
 const t=await getToken({req,secret:process.env.NEXTAUTH_SECRET});
 if(t?.authKind==="admin"&&process.env.ADMIN_CREDENTIAL_VERSION&&t.credVersion===process.env.ADMIN_CREDENTIAL_VERSION&&process.env.ADMIN_GITHUB_TOKEN)return {kind:"admin",subject:"admin",token:process.env.ADMIN_GITHUB_TOKEN,repo:await selected("admin",process.env.ADMIN_REPO||"xykal/XyRDP")};
 if(t?.authKind==="github"&&typeof t.accessToken==="string"&&typeof t.login==="string"&&/^[a-zA-Z0-9-]+$/.test(t.login))return {kind:"user",token:t.accessToken,repo:await selected("github:"+t.githubId,t.login+"/XyRDP"),subject:"github:"+t.githubId};
 throw new ApiError(401,"Silakan masuk kembali");
}
export async function github<T=Record<string,unknown>>(token:string,path:string,method="GET",data?:unknown):Promise<T>{
 const r=await fetch("https://api.github.com"+path,{method,headers:{Authorization:"Bearer "+token,"User-Agent":"RdpFree","Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28",...(data?{"Content-Type":"application/json"}:{})},body:data?JSON.stringify(data):undefined,cache:"no-store",signal:AbortSignal.timeout(25000)});
 if(!r.ok)throw new ApiError([401,403,404,409,422,429].includes(r.status)?r.status:502,r.status===422?"GitHub menolak data. Nama repo mungkin sudah dipakai atau parameter tidak valid.":"GitHub menolak permintaan ("+r.status+"). Periksa akses repository atau izin Actions.");
 return (r.status===204?{}:await r.json()) as T;
}
export async function gh<T=Record<string,unknown>>(ctx:Context,path:string,method="GET",data?:unknown):Promise<T>{return github<T>(ctx.token,"/repos/"+ctx.repo+path,method,data);}
export async function guarded(fn:()=>Promise<Response>){try{return await fn()}catch(e){return reply({error:e instanceof ApiError?e.message:"Layanan belum dapat memproses permintaan. Coba lagi."},e instanceof ApiError?e.status:503)}}
