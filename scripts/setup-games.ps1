# ============================================================================
#  setup-games.ps1 — Penyedia Game & Emulator Ready-to-Play di XyRDP:
#    1) Minecraft Java Edition (Otomatis Siap Pakai):
#       - Menghubungkan & menyuntikkan Mesa3D OpenGL 4.6 (llvmpipe) ke seluruh
#         runtime Java (Temurin JDK 21 & JRE 8 di C:\hostedtoolcache & Program Files)
#         agar bebas "GLFW error 65542: The driver does not appear to support OpenGL"
#       - Memasang TL Launcher (C:\Games\Minecraft\TL.jar + Launch-TLauncher.vbs)
#         dari mirror resmi bebas Cloudflare 403 (https://llaun.ch/jar)
#       - Memasang PrismLauncher Portable (C:\Games\PrismLauncher\prismlauncher.exe)
#         yang mendukung akun Microsoft maupun Offline
#       - Memasang Official Minecraft Launcher (C:\Games\Minecraft\MinecraftLauncher.exe)
#       - Preset options.txt 120 FPS ramah RDP di %APPDATA%\.minecraft
#    2) Minecraft Bedrock / Microsoft Store Xbox Identity
#    3) Roblox Player + ClientAppSettings Direct3D 11 120 FPS
# ============================================================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$XyTag                 = 'XyRDP:games'
. "$PSScriptRoot/lib-common.ps1"

function Test-OptIn([string]$Val) {
  if (-not $Val) { return $false }
  return @('ya','1','true','yes','on') -contains $Val.Trim().ToLower()
}

$wantRoblox  = Test-OptIn $env:ROBLOX
$wantMcJava  = Test-OptIn $env:MINECRAFT_JAVA
$wantMcBed   = Test-OptIn $env:MINECRAFT_BEDROCK

$work = 'C:\XyRDP\deps\games'
New-Item -ItemType Directory -Path $work -Force | Out-Null
New-Item -ItemType Directory -Path 'C:\Games' -Force | Out-Null

function Invoke-GameDownload([string]$Url, [string]$OutFile, [int]$MinBytes = 4096) {
  Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
  & curl.exe -fL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 180 -sS $Url -o $OutFile
  if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFile) -and (Get-Item $OutFile).Length -ge $MinBytes) {
    return $true
  }
  try {
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -UseBasicParsing -TimeoutSec 120
    return ((Test-Path $OutFile) -and (Get-Item $OutFile).Length -ge $MinBytes)
  } catch {
    return $false
  }
}

function Find-BestJavawExe {
  $candidates = @()
  foreach ($root in @(
    'C:\Program Files\Eclipse Adoptium',
    'C:\hostedtoolcache\windows\Java_Temurin-Hotspot_jdk',
    'C:\Program Files\Java',
    'C:\Program Files\Microsoft'
  )) {
    if (Test-Path $root) {
      $found = Get-ChildItem -Path $root -Recurse -File -Filter 'javaw.exe' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'x64|jdk-21|jdk-17|jre-21|jre-17' } |
        Sort-Object FullName -Descending
      if ($found) { $candidates += $found }
    }
  }
  if ($candidates.Count -gt 0) { return $candidates[0].FullName }
  $cmd = Get-Command javaw.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return 'javaw.exe'
}

function Install-JavaRuntimesForMinecraft([bool]$InstallMsiIfMissing) {
  # Cek apakah Temurin JDK 21 sudah tersedia di C:\hostedtoolcache atau C:\Program Files\Eclipse Adoptium
  $existingJavaw = Find-BestJavawExe
  $hasJava21 = ($existingJavaw -and (Test-Path $existingJavaw) -and ($existingJavaw -match '21\.'))

  if (-not $hasJava21 -and $InstallMsiIfMissing) {
    try {
      $jdk21Msi = Join-Path $work 'Temurin21-x64.msi'
      Log 'Mengunduh Eclipse Temurin JDK 21 LTS (x64) untuk Minecraft 1.21+...'
      if (Invoke-GameDownload 'https://api.adoptium.net/v3/installer/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse' $jdk21Msi 10000000) {
        Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$jdk21Msi`"", '/qn', '/norestart', 'ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome') -Wait -WindowStyle Hidden | Out-Null
        Log 'Eclipse Temurin JDK 21 LTS terpasang.'
      }
    } catch { Log "Instalasi JDK 21 warning: $($_.Exception.Message)" }
  }

  # Cek JRE 8 untuk Minecraft 1.8.9 / 1.12.2
  $hasJava8 = $false
  foreach ($r8 in @('C:\Program Files\Eclipse Adoptium', 'C:\hostedtoolcache\windows\Java_Temurin-Hotspot_jdk')) {
    if (Test-Path $r8) {
      if ((Get-ChildItem $r8 -Directory -Filter '*8*' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
        $hasJava8 = $true; break
      }
    }
  }
  if (-not $hasJava8 -and $InstallMsiIfMissing) {
    try {
      $jre8Msi = Join-Path $work 'Temurin8-x64.msi'
      Log 'Mengunduh Eclipse Temurin JRE 8 LTS (x64) untuk Minecraft 1.8.9/1.12.2...'
      if (Invoke-GameDownload 'https://api.adoptium.net/v3/installer/latest/8/ga/windows/x64/jre/hotspot/normal/eclipse' $jre8Msi 10000000) {
        Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$jre8Msi`"", '/qn', '/norestart') -Wait -WindowStyle Hidden | Out-Null
        Log 'Eclipse Temurin JRE 8 LTS terpasang.'
      }
    } catch { Log "Instalasi JRE 8 warning: $($_.Exception.Message)" }
  }

  # Pastikan JAVA_HOME & PATH sistem mengarah ke javaw.exe terbaik
  $best = Find-BestJavawExe
  if ($best -and (Test-Path $best)) {
    $binDir = Split-Path $best -Parent
    $homeDir = Split-Path $binDir -Parent
    $curPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if ($curPath -notlike "*$binDir*") {
      [Environment]::SetEnvironmentVariable('Path', "$binDir;$curPath", 'Machine')
      $env:Path = "$binDir;$env:Path"
    }
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $homeDir, 'Machine')
    $env:JAVA_HOME = $homeDir
  }
}

function Install-PrismLauncherPortable {
  $prismDir = 'C:\Games\PrismLauncher'
  if (Test-Path (Join-Path $prismDir 'prismlauncher.exe')) {
    return $true
  }
  New-Item -ItemType Directory -Path $prismDir -Force | Out-Null
  $sevenZip = 'C:\Program Files\7-Zip\7z.exe'
  if (-not (Test-Path $sevenZip)) { $sevenZip = "${env:ProgramFiles(x86)}\7-Zip\7z.exe" }

  # Prioritaskan build Portable yang mendukung akun Microsoft & Offline sekaligus, fallback ke upstream PrismLauncher
  foreach ($repo in @('Diegiwg/PrismLauncher-Cracked', 'PrismLauncher/PrismLauncher')) {
    try {
      $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" `
        -Headers @{ 'User-Agent' = 'XyRDP' } -TimeoutSec 20
      $asset = $rel.assets | Where-Object { $_.name -match 'Windows-MSVC-Portable-.*\.zip$' -and $_.name -notmatch 'arm64' } | Select-Object -First 1
      if (-not $asset) {
        $asset = $rel.assets | Where-Object { $_.name -match 'Windows.*Portable.*\.zip$' -and $_.name -notmatch 'arm64' } | Select-Object -First 1
      }
      if ($asset) {
        $zip = Join-Path $work $asset.name
        Log "Mengunduh PrismLauncher Portable dari $repo ($($asset.name))..."
        if (Invoke-GameDownload $asset.browser_download_url $zip 5000000) {
          if (Test-Path $sevenZip) { & $sevenZip x $zip "-o$prismDir" -y 2>&1 | Out-Null }
          else { Expand-Archive -Path $zip -DestinationPath $prismDir -Force }
          # Jika terekstrak ke dalam subfolder, pindahkan ke root $prismDir
          $exe = Get-ChildItem -Path $prismDir -Recurse -File -Filter 'prismlauncher.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
          if ($exe -and $exe.DirectoryName -ne $prismDir) {
            Get-ChildItem -Path $exe.DirectoryName -Force | ForEach-Object {
              Move-Item $_.FullName -Destination $prismDir -Force -ErrorAction SilentlyContinue
            }
          }
          if (Test-Path (Join-Path $prismDir 'prismlauncher.exe')) {
            $javaw = (Find-BestJavawExe) -replace '\\', '/'
            @(
              '[General]'
              'ApplicationTheme=dark'
              "JavaPath=$javaw"
              'MaxMemAlloc=4096'
              'MinMemAlloc=1024'
              'SkipJavaCompatibilityCheck=true'
              'SkipJavaWizard=true'
            ) | Set-Content -Path (Join-Path $prismDir 'prismlauncher.cfg') -Encoding UTF8 -Force
            Log "PrismLauncher Portable siap di $prismDir"
            return $true
          }
        }
      }
    } catch {
      Log "PrismLauncher ($repo) warning: $($_.Exception.Message)"
    }
  }
  return $false
}

function Install-MinecraftLaunchersSuite {
  $mcDir = 'C:\Games\Minecraft'
  New-Item -ItemType Directory -Path $mcDir -Force | Out-Null

  # 1. Unduh Official Minecraft Launcher (Minecraft.exe - 3.3 MB, selalu HTTP 200 dari Mojang)
  $offExe = Join-Path $mcDir 'MinecraftLauncher.exe'
  if (-not (Test-Path $offExe)) {
    if (Invoke-GameDownload 'https://launcher.mojang.com/download/Minecraft.exe' $offExe 1000000) {
      Log "Official Minecraft Launcher siap di $offExe"
    }
  }

  # 2. Unduh TL Legacy Launcher (TL.jar - 11 MB dari https://llaun.ch/jar yang bebas blokir Cloudflare 403)
  $tlJar = Join-Path $mcDir 'TL.jar'
  if (-not (Test-Path $tlJar)) {
    foreach ($u in @('https://llaun.ch/jar', 'https://dl.llaun.ch/legacy/bootstrap')) {
      if (Invoke-GameDownload $u $tlJar 2000000) {
        Log "Minecraft TL Launcher (TL.jar) berhasil diunduh dari $u"
        break
      }
    }
  }

  # Buat launcher script TLauncher.bat & Launch-TLauncher.vbs (tanpa jendela CMD hitam, langsung memanggil javaw.exe dengan OpenGL 4.6)
  $tlBat = Join-Path $mcDir 'TLauncher.bat'
  $batCode = @'
@echo off
set GALLIUM_DRIVER=llvmpipe
set LIBGL_ALWAYS_SOFTWARE=1
set MESA_GL_VERSION_OVERRIDE=4.6
set MESA_GLSL_VERSION_OVERRIDE=460
if exist "C:\XyRDP\grafis\Deploy-OpenGL-To-Java.ps1" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\XyRDP\grafis\Deploy-OpenGL-To-Java.ps1" >nul 2>&1
)
set "JAVAW=javaw.exe"
for /f "delims=" %%J in ('powershell.exe -NoProfile -Command "$c=@(Get-ChildItem 'C:\Program Files\Eclipse Adoptium','C:\hostedtoolcache\windows\Java_Temurin-Hotspot_jdk','C:\Program Files\Java' -Recurse -Filter javaw.exe -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'x64|jdk-21|jdk-17' } | Sort-Object FullName -Descending); if($c.Count){$c[0].FullName}"') do set "JAVAW=%%J"
if exist "C:\Games\Minecraft\TL.jar" (
  start "" "%JAVAW%" -Xmx4096M -Dsun.java2d.d3d=false -jar "C:\Games\Minecraft\TL.jar"
  exit /b 0
)
if exist "C:\Games\PrismLauncher\prismlauncher.exe" (
  start "" "C:\Games\PrismLauncher\prismlauncher.exe"
  exit /b 0
)
if exist "C:\Games\Minecraft\MinecraftLauncher.exe" (
  start "" "C:\Games\Minecraft\MinecraftLauncher.exe"
)
'@
  Set-Content -Path $tlBat -Value $batCode -Encoding ASCII -Force

  $tlVbs = Join-Path $mcDir 'Launch-TLauncher.vbs'
  $vbsCode = 'CreateObject("WScript.Shell").Run """C:\Games\Minecraft\TLauncher.bat""", 0, False'
  Set-Content -Path $tlVbs -Value $vbsCode -Encoding ASCII -Force
}

function Configure-MinecraftOpenGLAndOptions {
  # Pastikan Mesa3D OpenGL 4.6 sudah terpasang di System32, SysWOW64, dan C:\XyRDP\grafis\mesa-x64
  $mesaDll = 'C:\XyRDP\grafis\mesa-x64\opengl32.dll'
  if (-not (Test-Path $mesaDll)) {
    try {
      $env:GRAFIS = 'software'
      & "$PSScriptRoot/setup-grafis.ps1" 2>&1 | Out-Null
    } catch {}
  }
  $deployPs1 = 'C:\XyRDP\grafis\Deploy-OpenGL-To-Java.ps1'
  if (Test-Path $deployPs1) {
    try {
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $deployPs1 2>&1 | Out-Null
    } catch {}
  }

  # Siapkan folder .minecraft + options.txt ramah RDP (120 FPS, VSync Off, Raw Mouse Input On)
  $u = if ($env:RDP_USER) { $env:RDP_USER.Trim() } else { (Get-Cfg).rdp_user }
  foreach ($profUser in @($u, 'runneradmin', 'xyadmin')) {
    if (-not $profUser) { continue }
    $userRoot = "C:\Users\$profUser"
    if (-not (Test-Path $userRoot)) { continue }
    $mcDir = Join-Path $userRoot 'AppData\Roaming\.minecraft'
    New-Item -ItemType Directory -Path $mcDir -Force -ErrorAction SilentlyContinue | Out-Null
    $optFile = Join-Path $mcDir 'options.txt'
    if (-not (Test-Path $optFile)) {
      @(
        'version:3953'
        'autoJump:false'
        'enableVsync:false'
        'maxFps:120'
        'renderDistance:8'
        'simulationDistance:6'
        'graphicsMode:0'
        'ao:false'
        'Clouds:false'
        'particles:1'
        'mipmapLevels:0'
        'rawMouseInput:true'
        'fullscreen:false'
        'guiScale:2'
      ) | Set-Content -Path $optFile -Encoding ASCII -Force
    }
  }

  # Buat shortcut di Desktop User & Public Desktop
  foreach ($desk in @("C:\Users\$u\Desktop", "C:\Users\Public\Desktop", "C:\Users\Default\Desktop")) {
    New-Item -ItemType Directory -Path $desk -Force -ErrorAction SilentlyContinue | Out-Null
    try {
      $wsh = New-Object -ComObject WScript.Shell
      $iconExe = 'C:\Games\Minecraft\MinecraftLauncher.exe'

      if (Test-Path 'C:\Games\Minecraft\Launch-TLauncher.vbs') {
        $lnk = $wsh.CreateShortcut((Join-Path $desk 'Minecraft (TLauncher).lnk'))
        $lnk.TargetPath = 'wscript.exe'
        $lnk.Arguments = '"C:\Games\Minecraft\Launch-TLauncher.vbs"'
        $lnk.WorkingDirectory = 'C:\Games\Minecraft'
        if (Test-Path $iconExe) { $lnk.IconLocation = "$iconExe,0" }
        $lnk.Description = 'Minecraft Java Edition (TL Launcher + OpenGL 4.6 Ready)'
        $lnk.Save()
      }

      if (Test-Path 'C:\Games\PrismLauncher\prismlauncher.exe') {
        $lnk2 = $wsh.CreateShortcut((Join-Path $desk 'PrismLauncher (Minecraft).lnk'))
        $lnk2.TargetPath = 'C:\Games\PrismLauncher\prismlauncher.exe'
        $lnk2.WorkingDirectory = 'C:\Games\PrismLauncher'
        $lnk2.IconLocation = 'C:\Games\PrismLauncher\prismlauncher.exe,0'
        $lnk2.Description = 'PrismLauncher Portable (Microsoft & Offline Accounts + OpenGL 4.6)'
        $lnk2.Save()
      }

      if (Test-Path $iconExe) {
        $lnk3 = $wsh.CreateShortcut((Join-Path $desk 'Minecraft Official Launcher.lnk'))
        $lnk3.TargetPath = $iconExe
        $lnk3.WorkingDirectory = 'C:\Games\Minecraft'
        $lnk3.IconLocation = "$iconExe,0"
        $lnk3.Description = 'Official Minecraft Launcher'
        $lnk3.Save()
      }
    } catch {}
  }
}

$report = @{}

# Selalu siapkan Minecraft Java Suite (TL Launcher + PrismLauncher + Official Launcher + OpenGL 4.6 Injection)
# karena ukuran totalnya hanya ~32 MB (~4 detik di runner) sehingga Minecraft SELALU bisa dibuka di XyRDP!
Log 'Menyiapkan Minecraft Java Edition (Java 21/8 + TL Launcher + PrismLauncher + Mesa3D OpenGL 4.6)...'
Install-JavaRuntimesForMinecraft -InstallMsiIfMissing:$wantMcJava
$prismOk = Install-PrismLauncherPortable
Install-MinecraftLaunchersSuite
Configure-MinecraftOpenGLAndOptions

$report['minecraft_java'] = @{
  status        = 'ready'
  prismlauncher = $prismOk
  tlauncher_jar = (Test-Path 'C:\Games\Minecraft\TL.jar')
  official_exe  = (Test-Path 'C:\Games\Minecraft\MinecraftLauncher.exe')
  opengl46      = (Test-Path 'C:\XyRDP\grafis\mesa-x64\opengl32.dll')
}

# 2. Minecraft Bedrock & Official MSI Installer (bila dipilih)
if ($wantMcBed) {
  Log 'Menyiapkan Minecraft Bedrock & Xbox Identity Dependencies...'
  try {
    $wg = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($wg) {
      & winget install --id Mojang.MinecraftLauncher --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    }
  } catch {}
  $mcMsi = Join-Path $work 'MinecraftInstaller.msi'
  if (Invoke-GameDownload 'https://launcher.mojang.com/download/MinecraftInstaller.msi' $mcMsi 1000000) {
    Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$mcMsi`"", '/qn', '/norestart') -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    $report['minecraft_bedrock'] = @{ status = 'installed'; path = $mcMsi }
  }
}

# 3. Roblox Player (bila dipilih)
if ($wantRoblox) {
  Log 'Menyiapkan Roblox Player...'
  $rbxExe = Join-Path $work 'RobloxPlayerInstaller.exe'
  if (Invoke-GameDownload 'https://setup.rbxcdn.com/RobloxPlayerInstaller.exe' $rbxExe 1000000) {
    $u = if ($env:RDP_USER) { $env:RDP_USER.Trim() } else { (Get-Cfg).rdp_user }
    foreach ($desk in @("C:\Users\$u\Desktop", "C:\Users\Public\Desktop")) {
      New-Item -ItemType Directory -Path $desk -Force -ErrorAction SilentlyContinue | Out-Null
      Copy-Item $rbxExe (Join-Path $desk 'Install Roblox Player.exe') -Force -ErrorAction SilentlyContinue
    }
    try {
      Start-Process -FilePath $rbxExe -ArgumentList @('-quiet') -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    $report['roblox'] = 'ready'
    Log 'Roblox Player siap di Desktop.'
  } else {
    $report['roblox'] = 'download-failed'
  }
}

Update-Status @{ games = $report } | Out-Null
exit 0
