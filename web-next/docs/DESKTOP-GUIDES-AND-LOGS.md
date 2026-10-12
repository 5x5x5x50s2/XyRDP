# Desktop diagnostics, guides and logs

Updated 2026-10-12. Credit: KallAncrit.

- Page-specific Indonesian/English numbered guides cover Home, Connection, Setup, Settings, Games, Logs, Devices and Folder. Animated highlighting respects reduced-motion preference.
- Browser SpeechSynthesis is click-to-play only, with Stop and readable error fallback. No audio is played on navigation. Voice availability/quality depends on the user's OS/browser; physical device audio has not been verified.
- New GitHub sign-ins see a profile-publication notice and new community records default visible. Existing privacy values are never overwritten. A legacy session first seen only by heartbeat remains private. No checkbox gates counts; a button can hide/show a public profile. The explanatory paragraph under homepage statistics is removed.
- Home live status polls every 8 seconds while visible, with overlapping fetches prevented. It is polling, not instant push streaming; GitHub latency/rate limits remain relevant.
- Workflow session step is named SUDAH ONLINE. Logs have UTC timestamps and the online summary shows private IP, port, username and expiry. Passwords remain in GitHub Secrets/encrypted dashboard storage, never intentionally printed in public logs.
- New sessions include C:\ProgramData\RdpFree\Diagnose-Desktop.ps1. Default operation is local read-only diagnostics (OS, display drivers, selected processes, runtime files, installed apps and filtered recent event IDs). There is no environment/command-line dump or automatic upload. Review the local JSON before sharing.
- Optional -RestartExplorer must be invoked by the user in an interactive session; service session 0 is refused. Only Explorer in that session is restarted. This is not a Windows reboot, a guaranteed blackscreen fix, or an RDP-service restart.
- Cleanup no longer calls folder counts estimated GB. It reports actual free-space delta and remaining/failed targets. The Remove-Tree helper refuses protected OS/runtime/Tailscale/RdpFree paths. This is a safeguard/reporting change, not proof of additional storage freed; no destructive deep-clean benchmark was run in this update.

Validation: 20 web unit tests passed; browser tests verified guides, simulated TTS calls/stop/error, mobile layout, reduced motion and homepage changes. Windows CI run 38260700061 passed script parsing, protected-path guards with deletion mocked, and actual read-only diagnostic execution on Windows Server 2022 and 2025. No game was launched, existing RDP session stopped, or actual blackscreen reproduced/fixed during these tests.

For black screen with pointer: send Ctrl+Alt+End via the RDP client, open Task Manager, Run new task > explorer.exe. If Explorer already exists, use its Restart action. If unchanged, record the last installed app and time and collect diagnostics. Do not end the Actions job just to gather evidence; ephemeral machines are discarded at job end.
