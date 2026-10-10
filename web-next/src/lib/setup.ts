import {Context,ApiError,gh} from "./api";
import {db} from "./db";
import {loadSettings} from "./workflow";
export const TEMPLATE="xykal/XyRDP";
export async function inspect(c:Context){
 const mapping=await db().prepare("SELECT state FROM repositories WHERE subject=? AND repo=?").bind(c.subject,c.repo).first<{state:string}>();
 const result={repo:c.repo,template:TEMPLATE,exists:false,workflow_exists:false,workflow_state:"",actions_enabled:false,can_write:false,missing:[] as string[],ready:false,importing:mapping?.state==="initializing",password_stored:false};
 let repo:{permissions?:{push?:boolean;admin?:boolean}};
 try{repo=await gh(c,"");}catch(e){if(e instanceof ApiError&&e.status===404)return result;throw e}
 result.exists=true;result.can_write=!!repo.permissions?.push;
 try{const w=await gh<{state:string}>(c,"/actions/workflows/rdp-6h.yml");result.workflow_exists=true;result.workflow_state=w.state;}catch(e){if(!(e instanceof ApiError&&e.status===404))throw e;}
 if(!result.can_write)return result;
 const permissions=await gh<{enabled:boolean}>(c,"/actions/permissions");result.actions_enabled=permissions.enabled;
 const secrets=await gh<{secrets:{name:string}[]}>(c,"/actions/secrets?per_page=100");const names=secrets.secrets.map(s=>s.name);const inputs=await loadSettings(c.repo);
 const required=["RDP_PASSWORD",...(inputs.akses!=="tunnel"?["TAILSCALE_AUTH_KEY"]:[]),...(inputs.tunnel_provider==="ngrok"?["NGROK_AUTHTOKEN"]:[])];result.missing=required.filter(k=>!names.includes(k));
 const vault=await db().prepare("SELECT repo FROM credentials WHERE repo=?").bind(c.repo).first();result.password_stored=!!vault;
 result.ready=result.workflow_exists&&result.workflow_state==="active"&&result.actions_enabled&&!result.missing.length&&!result.importing;
 return result;
}
export async function finishSetup(c:Context){
 const state=await db().prepare("SELECT state FROM repositories WHERE subject=? AND repo=?").bind(c.subject,c.repo).first<{state:string}>();
 // Only a repo created by this onboarding flow is eligible for template cleanup.
 if(state?.state==="initializing"){
  const repo=await gh<{default_branch:string}>(c,"");const branch=repo.default_branch;
  const ref=await gh<{object:{sha:string}}>(c,"/git/ref/heads/"+encodeURIComponent(branch));
  const commit=await gh<{tree:{sha:string}}>(c,"/git/commits/"+ref.object.sha);
  const root=await gh<{tree:{path:string;mode:string;type:string;sha:string}[]}>(c,"/git/trees/"+commit.tree.sha);
  const keep=root.tree.filter(x=>!["web","web-next","deploy"].includes(x.path)).map(({path,mode,type,sha})=>({path,mode,type,sha}));
  if(keep.length!==root.tree.length){
   const tree=await gh<{sha:string}>(c,"/git/trees","POST",{tree:keep});
   const next=await gh<{sha:string}>(c,"/git/commits","POST",{message:"chore: repository RDP tanpa dashboard web — credit KallAncrit",tree:tree.sha,parents:[ref.object.sha]});
   await gh(c,"/git/refs/heads/"+encodeURIComponent(branch),"PATCH",{sha:next.sha,force:false});
  }
 }
 await gh(c,"/actions/permissions","PUT",{enabled:true,allowed_actions:"all"});
 await gh(c,"/actions/permissions/workflow","PUT",{default_workflow_permissions:"write",can_approve_pull_request_reviews:false});
 await gh(c,"/actions/workflows/rdp-6h.yml/enable","PUT");
 await db().prepare("UPDATE repositories SET state='ready',updated=? WHERE subject=? AND repo=?").bind(Date.now(),c.subject,c.repo).run();
}
