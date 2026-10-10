import {ApiError,Context,gh} from "./api";
import {db} from "./db";
export const choices:Record<string,string[]>={durasi_menit:["15","30","60","120","180","240","300","330","360"],akses:["tunnel","tailscale","semua"],tunnel_provider:["otomatis","pinggy","bore","ngrok","localhost.run","serveo"],storage_boost:["ya","tidak"],debloat:["ringan","full","tidak"],samp:["ya","tidak"],samp_extra:["ya","tidak"],win10:["ya","tidak"],xydesk:["ya","tidak"],ekstra:["ya","tidak"],grafis:["software","tidak"]};
export const defaults:Record<string,string>={durasi_menit:"360",hostname:"rdpfree",rdp_user:"xyadmin",akses:"tunnel",tunnel_provider:"otomatis",storage_boost:"ya",debloat:"ringan",samp:"ya",samp_extra:"tidak",gta_sa_url:"",win10:"ya",xydesk:"ya",ekstra:"ya",grafis:"software",wallpaper_url:""};
export function validate(raw:Record<string,unknown>){const inputs={...defaults};for(const [k,v] of Object.entries(raw)){if(!(k in defaults)||typeof v!=="string")throw new ApiError(400,"Parameter tidak dikenal: "+k);inputs[k]=v;}
 for(const [k,allowed] of Object.entries(choices))if(!allowed.includes(inputs[k]))throw new ApiError(400,"Pilihan tidak valid: "+k);
 if(!/^[a-zA-Z0-9][a-zA-Z0-9-]{0,29}$/.test(inputs.hostname))throw new ApiError(400,"Hostname harus 1–30 huruf, angka, atau tanda minus");
 if(!/^[a-zA-Z][a-zA-Z0-9_-]{2,19}$/.test(inputs.rdp_user)||/^(administrator|guest|defaultaccount|wdagutilityaccount|system|localservice|networkservice|con|prn|aux|nul)$/i.test(inputs.rdp_user))throw new ApiError(400,"Username RDP tidak valid");
 for(const k of ["gta_sa_url","wallpaper_url"]){if(inputs[k]){try{const u=new URL(inputs[k]);if(u.protocol!=="https:"||u.username||u.password||inputs[k].length>2000)throw Error();}catch{throw new ApiError(400,k+" harus URL HTTPS")}}}return inputs;}
export async function loadSettings(repo:string){const r=await db().prepare("SELECT inputs FROM settings WHERE repo=?").bind(repo).first<{inputs:string}>();return r?validate(JSON.parse(r.inputs)):{...defaults};}
export type Run={id:number;status:string;conclusion:string|null;created_at:string;run_started_at:string;html_url:string;name:string;workflow_id:number};
export async function runs(ctx:Context){return (await gh<{workflow_runs:Run[]}>(ctx,"/actions/workflows/rdp-6h.yml/runs?per_page=30")).workflow_runs;}
export const active=(r:Run)=>["queued","in_progress","waiting","requested","pending"].includes(r.status);
