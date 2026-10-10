import {getServerSession} from "next-auth";
import {authOptions} from "@/lib/auth";
export async function GET(){const session=await getServerSession(authOptions);const headers={"Cache-Control":"private, no-store"};if(!session)return Response.json({error:"unauthorized"},{status:401,headers});if(session.role!=="admin")return Response.json({error:"forbidden"},{status:403,headers});return Response.json({role:"admin",login:session.user?.name},{headers})}
