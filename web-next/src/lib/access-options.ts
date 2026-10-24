import type {Context} from './api';
// Akses RDP hanya Tailscale (portmap/railway dihapus 2026-10-24).
export async function requirePortmapConfiguration(_c:Context,_inputs:Record<string,string>){return;}
