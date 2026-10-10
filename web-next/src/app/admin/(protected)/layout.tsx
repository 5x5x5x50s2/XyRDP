import {getServerSession} from "next-auth";
import {authOptions} from "@/lib/auth";
import {redirect} from "next/navigation";
import Link from "next/link";
import Logout from "@/app/dashboard/logout";
export default async function Layout({children}:{children:React.ReactNode}){const session=await getServerSession(authOptions);if(session?.role!=="admin")redirect("/admin/login");return <><header><b>RdpFree / Admin</b><nav><Link href="/admin">Admin</Link><Link href="/dashboard">Home</Link><Link href="/dashboard/setup">Setup</Link><Link href="/dashboard/folder">Folder</Link><Link href="/dashboard/logs">Logs</Link><Link href="/dashboard/settings">Settings</Link><Link href="/dashboard/devices">XyDesk</Link></nav><span>{session.user?.name}</span><Logout/></header><main>{children}</main><footer>Credit: KallAncrit</footer></>}
