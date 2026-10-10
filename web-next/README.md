# RdpFree — Next.js + Cloudflare Workers

Live: https://rdpfree.projectkal.my.id

Next.js 15.5.27, NextAuth 4, OpenNext, Workers and D1. Node 22+.

## Implemented
- Separate public GitHub login and private `/admin/login` email/password + managed Turnstile login.
- Public pages contain no admin navigation. Authorization is server-enforced, not based on hiding the URL.
- Admin password verifier uses a random salt and PBKDF2-SHA256 (100,000 rounds; Workers WebCrypto limit) for a long randomly generated password. Constant-time verifier comparison, Turnstile hostname/action verification, and D1-backed five-attempt/15-minute IP limit.
- OAuth cannot confer admin access. Admin sessions are invalidated by rotating `ADMIN_CREDENTIAL_VERSION`.
- Encrypted HttpOnly cookies; 30-day maximum, no localStorage auth or session access-token exposure.
- Dashboard: current workflow status, connection and expiry countdown; start/stop with confirmation.
- Repository-scoped settings persisted in D1, all 16 workflow inputs validated. Custom dropdowns.
- Nested folder browsing, small-file preview, job/step status and links to GitHub logs.
- Revocable 30-day native-device tokens for XyDesk. See [API contract](docs/XYDESK-API.md).
- GitHub secrets remain managed in GitHub, not readable by dashboard.

## Runtime configuration

Worker secrets: `NEXTAUTH_URL`, `NEXTAUTH_SECRET`, `GITHUB_ID`, `GITHUB_SECRET`, `ADMIN_EMAIL`, `ADMIN_PASSWORD_HASH`, `ADMIN_CREDENTIAL_VERSION`, `ADMIN_REPO`, `ADMIN_GITHUB_TOKEN`, `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET_KEY`.

`NEXTAUTH_URL=https://rdpfree.projectkal.my.id`; OAuth callback is `/api/auth/callback/github` on that origin. Turnstile widget is restricted to this hostname and uses action `admin_login`. Admin password and Turnstile are configured; the credential handoff file is outside the repository.

Cloudflare D1 binding `DB`, schema in `schema.sql`. Runtime auth secrets must be stable across builds; do not rotate `NEXTAUTH_SECRET` casually as it encrypts browser sessions and stored device grants. A stolen device must be revoked independently.

```
npm ci
npm run lint
npm run build:worker
npm run deploy
```

## Verification and limitations

Production Next/OpenNext builds and lint pass. Live synthetic-session checks verify admin/user separation, unauthenticated rejection, D1 settings reads, authenticated GitHub reads, Origin enforcement, invalid duration rejection, explicit dispatch confirmation, device creation, restricted device access and revocation. These tests do not bypass or validate a real user's Turnstile interaction.

No real workflow was dispatched/stopped during the migration tests; this avoids consuming Actions minutes. Full human Turnstile login, a complete real RDP run, and an installed Android APK end-to-end session still need acceptance testing. Full raw logs and Actions secrets management remain on GitHub. This project does not guarantee GitHub account eligibility or prevent enforcement.

Credit: KallAncrit.
