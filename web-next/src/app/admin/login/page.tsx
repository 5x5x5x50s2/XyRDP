import {getServerSession} from "next-auth";
import {authOptions} from "@/lib/auth";
import {redirect} from "next/navigation";
import Link from "next/link";
import Button from "./button";
export default async function Login(){const session=await getServerSession(authOptions);if(session?.role==="admin")redirect("/admin");return <main className="login"><span className="eyebrow">RdpFree / Admin</span><h1>Ruang admin.</h1><section className="card"><h2>Masuk dengan akun pemilik</h2><p>Akses admin diperiksa di server berdasarkan ID akun GitHub yang diizinkan.</p>{session&&<p className="error">Akun yang sedang aktif tidak memiliki akses admin. Gunakan akun GitHub pemilik.</p>}<Button/></section><p><Link href="/login">← Kembali ke login pengguna</Link></p><footer>Credit: KallAncrit</footer></main>}
