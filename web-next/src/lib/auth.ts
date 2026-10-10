import type { NextAuthOptions } from "next-auth";
import GitHubProvider from "next-auth/providers/github";
export const authOptions: NextAuthOptions = {
 secret: process.env.NEXTAUTH_SECRET,
 providers: [GitHubProvider({clientId: process.env.GITHUB_ID || "", clientSecret: process.env.GITHUB_SECRET || "", authorization: {params: {scope: "read:user repo workflow"}}})],
 session: {strategy: "jwt", maxAge: 30*24*60*60},
 pages: {signIn: "/login"},
 callbacks: {
  async jwt({token,account,profile}) {
   if(account?.provider === "github") {
    token.accessToken=account.access_token;
    token.login=(profile as {login?:string})?.login;
    token.githubId=account.providerAccountId;
   }
   const allowed=(process.env.ADMIN_GITHUB_IDS || "").split(",").map(s=>s.trim()).filter(Boolean);
   token.role=typeof token.githubId === "string" && allowed.includes(token.githubId)?"admin":"user";
   return token;
  },
  async session({session,token}) {
   if(session.user) session.user.name=String(token.login || session.user.name || "");
   session.role=token.role === "admin"?"admin":"user";
   return session;
  }
 }
};
