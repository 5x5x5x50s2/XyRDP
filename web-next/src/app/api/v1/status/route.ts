import {NextRequest} from "next/server";
import {context,guarded,reply,gh,ApiError} from "@/lib/api";
import {runs,active} from "@/lib/workflow";
type StatusFile={run_id?:string;active?:boolean;started_at?:string;expires_at?:string;rdp_user?:string;hostname?:string;akses?:{tunnel?:{host?:string;port?:number;status?:string};tailscale?:{ip?:string;status?:string}}};
export async function GET(req:NextRequest){return guarded(async()=>{const c=await context(req);const list=await runs(c);const run=list.find(active)||list[0]||null;let session:StatusFile|null=null;
 try{const f=await gh<{content:string}>(c,"/contents/rdp-status.json?ref=status");session=JSON.parse(Buffer.from(f.content,"base64").toString("utf8").replace(/^\uFEFF/,""));}catch(e){if(!(e instanceof ApiError&&e.status===404))throw e}
 const current=!!(run&&active(run)&&session&&String(session.run_id)===String(run.id)&&session.active&&Date.parse(session.expires_at||"")>Date.now());
 const tunnel=current?session?.akses?.tunnel:null,ts=current?session?.akses?.tailscale:null;
 const host=tunnel?.status==="ok"?tunnel.host:ts?.status==="ok"?ts.ip:null;
 const connection=host?{host,port:tunnel?.status==="ok"?Number(tunnel.port):3389,username:session?.rdp_user||"xyadmin",password_required:true,transport:tunnel?.status==="ok"?"tunnel":"tailscale"}:null;
 return reply({repo:c.repo,run,active:!!run&&active(run),session:current?{hostname:session?.hostname,started_at:session?.started_at,expires_at:session?.expires_at,username:session?.rdp_user}:null,connection,server_time:new Date().toISOString(),phase:current?(connection?"ready":"preparing"):(run&&active(run)?"preparing":"stopped")});})}
