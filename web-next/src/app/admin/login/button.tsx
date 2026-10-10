"use client";
import {signIn} from "next-auth/react";
export default function Button(){return <button onClick={()=>signIn("github",{callbackUrl:"/admin"})}>Masuk sebagai admin →</button>}
