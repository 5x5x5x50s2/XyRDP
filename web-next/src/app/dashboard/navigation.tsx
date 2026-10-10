"use client";
import {useState,useRef} from "react";
import {usePathname} from "next/navigation";
import Link from "next/link";
import Logout from "./logout";
export default function Navigation({admin=false,name}:{admin?:boolean;name?:string|null}){
 const [open,setOpen]=useState(false),button=useRef<HTMLButtonElement>(null);const path=usePathname();
 const links=[...(admin?[["Admin","/admin"],["GitHub App","/admin/github-app"]]:[]),...[['Home',''],['Hubungkan','/connection'],['Setup','/setup'],['Games','/games'],['Folder','/folder'],['Settings','/settings'],['Logs','/logs'],['XyDesk','/devices']].map(([label,url])=>[label,'/dashboard'+url])];
 return <header className="workspace-header" onKeyDown={e=>{if(e.key==='Escape'){setOpen(false);button.current?.focus()}}}>
 <Link className="brand" href={admin?'/admin':'/dashboard'}><svg width="28" height="28" viewBox="0 0 32 32" fill="none" aria-hidden="true"><rect x="3" y="5" width="26" height="18" rx="5" stroke="currentColor" strokeWidth="2"/><path d="M10 28h12M16 23v5M10 11l5 5-5 5M18 17h5" stroke="currentColor" strokeWidth="2"/></svg><b>RdpFree{admin?' / Admin':''}</b></Link>
 <button ref={button} className="menu-toggle secondary" aria-label={open?'Tutup menu':'Buka menu'} aria-expanded={open} aria-controls="workspace-navigation" onClick={()=>setOpen(!open)}><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">{open?<path d="m6 6 12 12M18 6 6 18"/>:<path d="M4 6h16M4 12h16M4 18h16"/>}</svg></button>
 <div id="workspace-navigation" className={'workspace-menu'+(open?' is-open':'')}><nav aria-label={admin?'Navigasi admin':'Navigasi workspace'}>{links.map(([label,url])=><Link key={url} href={url} aria-current={path===url?'page':undefined} onClick={()=>setOpen(false)}>{label}</Link>)}</nav><div className="nav-account"><span>{name}</span><Logout/></div></div></header>
}
