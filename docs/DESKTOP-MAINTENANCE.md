# Desktop maintenance — 2026-10-13

- Retired TranslucentTB download/install/startup provisioning. Legacy configuration
  values are ignored; new sessions use native opaque taskbar settings. This does
  not remotely uninstall software from an already-running RDP session.
- Lightshot enabled in template config. Use official vendor installer, verify
  Authenticode and Skillbrains publisher, request all-users install, enforce a
  180-second installer wait, check exit code and actual executable. Startup paths
  are quoted. Remove unnecessary inbound firewall permission and unverified mirror.
- Mesa remains optional, now staged as an isolated toolkit with upstream files.
  Never overwrite System32, change system-DLL ownership, or force software OpenGL/
  Vulkan globally. This is not a physical GPU, a D3D9 game fix, or a measured FPS
  improvement. Previous system-wide modifications in existing sessions are not
  automatically reverted. Read C:\XyRDP\grafis\README.txt before per-app setup.
- RDP password masking is unchanged. Temporary sessions do not make durable
  public workflow logs private. Credentials remain in the protected dashboard.
- Added manual Windows-2022 validation for parsing and repeat Lightshot installation;
  it does not start an RDP session or install games.
