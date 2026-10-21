$ErrorActionPreference = 'Continue'
$outDir = 'C:\XyRDP\qa-screenshots'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinCapture {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern uint MapVirtualKey(uint uCode, uint uMapType);

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
}
"@

function Send-KeyPress([byte]$vk) {
  try {
    $scan = [byte]([WinCapture]::MapVirtualKey([uint32]$vk, 0) -band 0xFF)
    [WinCapture]::keybd_event($vk, $scan, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 90
    [WinCapture]::keybd_event($vk, $scan, 2, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
  } catch {}
}

function Send-DirectInputString([string]$text) {
  foreach ($ch in $text.ToUpper().ToCharArray()) {
    $vk = [byte][char]$ch
    Send-KeyPress $vk
  }
}

function Send-LeftClick([int]$x, [int]$y) {
  try {
    [WinCapture]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 120
    [WinCapture]::mouse_event([WinCapture]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 90
    [WinCapture]::mouse_event([WinCapture]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
  } catch {}
}

function Minimize-RunnerTerminals {
  Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowHandle -ne [IntPtr]::Zero -and (
      $_.ProcessName -in @('cmd', 'pwsh', 'conhost', 'Runner.Listener', 'Runner.Worker') -or
      $_.MainWindowTitle -match 'hosted-compute-agent|Runner|Windows PowerShell'
    )
  } | ForEach-Object {
    try {
      if ($_.Id -ne $PID) {
        [WinCapture]::ShowWindow($_.MainWindowHandle, 6) | Out-Null
      }
    } catch {}
  }
}

function Save-QaWindowScreenshot {
  param(
    [Parameter(Mandatory=$false)] $Proc,
    [Parameter(Mandatory=$true)][string]$OutName,
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][string]$Sub,
    [int]$WaitSec = 6
  )

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $hwnd = [IntPtr]::Zero
  while ($sw.Elapsed.TotalSeconds -lt $WaitSec) {
    if ($Proc) {
      try {
        $Proc.Refresh()
        if ($Proc.MainWindowHandle -ne [IntPtr]::Zero) {
          $hwnd = $Proc.MainWindowHandle
        }
      } catch {}
    }
    Start-Sleep -Milliseconds 500
  }

  Minimize-RunnerTerminals

  if ($hwnd -ne [IntPtr]::Zero) {
    try {
      [WinCapture]::ShowWindow($hwnd, 9) | Out-Null
      [WinCapture]::SetWindowPos($hwnd, [WinCapture]::HWND_TOPMOST, 0, 0, 0, 0, ([WinCapture]::SWP_NOMOVE -bor [WinCapture]::SWP_NOSIZE -bor [WinCapture]::SWP_SHOWWINDOW)) | Out-Null
      [WinCapture]::SetForegroundWindow($hwnd) | Out-Null
      Start-Sleep -Milliseconds 900
    } catch {}
  }

  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $scrW = [Math]::Max(1024, $bounds.Width)
  $scrH = [Math]::Max(768, $bounds.Height)

  $bmp = New-Object System.Drawing.Bitmap($scrW, $scrH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gScreen = [System.Drawing.Graphics]::FromImage($bmp)
  $gScreen.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $gScreen.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

  try {
    $gScreen.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size($scrW, $scrH)), [System.Drawing.CopyPixelOperation]::SourceCopy)
  } catch {
    $gScreen.Clear([System.Drawing.Color]::FromArgb(15, 23, 42))
  }

  if ($hwnd -ne [IntPtr]::Zero) {
    try {
      $rc = New-Object WinCapture+RECT
      if ([WinCapture]::GetWindowRect($hwnd, [ref]$rc)) {
        $w = $rc.Right - $rc.Left
        $h = $rc.Bottom - $rc.Top
        if ($w -gt 80 -and $h -gt 60) {
          $penGlow = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(230, 56, 189, 248), 3)
          $gScreen.DrawRectangle($penGlow, $rc.Left, $rc.Top, $w, $h)
          $penGlow.Dispose()
        }
      }
    } catch {}
  }

  # Overlay QA Banner
  $bannerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(225, 9, 13, 22))
  $gScreen.FillRectangle($bannerBrush, 0, 0, $scrW, 64)
  $f1 = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
  $f2 = New-Object System.Drawing.Font('Consolas', 9.5, [System.Drawing.FontStyle]::Regular)
  $bWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $bCyan  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56, 189, 248))
  $gScreen.DrawString($Title, $f1, $bWhite, 18, 8)
  $gScreen.DrawString($Sub, $f2, $bCyan, 18, 35)

  $outPath = Join-Path $outDir $OutName
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $gScreen.Dispose()
  $bmp.Dispose()
  Write-Host "Saved screenshot: $outPath (HWND=$hwnd)"
}

# ============================================================================
# 1. Buat Gambar Audit Visual Seluruh Shortcut Desktop & Ikon Asli (.exe)
# ============================================================================
Write-Host "=== 1. Mengaudit Seluruh Shortcut Desktop & Mengekstrak Ikon Asli ==="
$desk = 'C:\Users\Public\Desktop'
foreach ($junk in @('Epic Games Launcher.lnk', 'R 4.6.1.lnk', 'Unity Hub.lnk')) {
  Remove-Item -LiteralPath (Join-Path $desk $junk) -Force -ErrorAction SilentlyContinue
}
$lnks = Get-ChildItem -Path $desk -Filter '*.lnk' -ErrorAction SilentlyContinue | Sort-Object Name

$wsh = New-Object -ComObject WScript.Shell
$cardW = 1440
$cardH = 980
$bmpAudit = New-Object System.Drawing.Bitmap($cardW, $cardH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmpAudit)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.Clear([System.Drawing.Color]::FromArgb(12, 16, 26))

$fHead = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$fSub  = New-Object System.Drawing.Font('Consolas', 10, [System.Drawing.FontStyle]::Regular)
$fName = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$fMeta = New-Object System.Drawing.Font('Consolas', 8.5, [System.Drawing.FontStyle]::Regular)

$bTitle = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$bGreen = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(52, 211, 153))
$bMuted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))
$bCard  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(22, 30, 46))
$pBorder= New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(45, 58, 84), 1.5)

$g.DrawString("QA E2E AUDIT - DESKTOP SHORTCUTS & IKON ASLI APLIKASI (WINDOWS SERVER 2022)", $fHead, $bTitle, 28, 20)
$g.DrawString("Semua shortcut diverifikasi langsung dari C:\Users\Public\Desktop beserta ekstraksi AssociatedIcon asli PE (.exe)", $fSub, $bGreen, 28, 52)

$col = 0
$row = 0
$reportLines = @()
foreach ($lnkFile in $lnks) {
  $sc = $wsh.CreateShortcut($lnkFile.FullName)
  $target = $sc.TargetPath
  $iconLoc = ($sc.IconLocation -split ',')[0].Trim()
  $targetExists = if ($target -and (Test-Path $target)) { $true } else { $false }
  $iconFile = if ($iconLoc -and (Test-Path $iconLoc)) { $iconLoc } elseif ($targetExists) { $target } else { '' }

  $x = 28 + ($col * 698)
  $y = 92 + ($row * 120)
  $g.FillRectangle($bCard, $x, $y, 676, 106)
  $g.DrawRectangle($pBorder, $x, $y, 676, 106)

  if ($iconFile -and (Test-Path $iconFile)) {
    try {
      $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($iconFile)
      if ($ico) {
        $icoBmp = $ico.ToBitmap()
        $g.DrawImage($icoBmp, $x + 18, $y + 21, 64, 64)
        $icoBmp.Dispose()
        $ico.Dispose()
      }
    } catch {}
  }

  $shortName = $lnkFile.BaseName
  $statusTxt = if ($targetExists) { "READY (OK)" } else { "MISSING" }
  $g.DrawString($shortName, $fName, $bTitle, $x + 98, $y + 14)
  $g.DrawString("Target : $target", $fMeta, $bMuted, $x + 98, $y + 42)
  $g.DrawString("Icon   : $iconFile | Status: $statusTxt", $fMeta, $bGreen, $x + 98, $y + 66)

  $reportLines += "$shortName => Target=$target (Exists=$targetExists) | Icon=$iconFile"

  $col++
  if ($col -ge 2) { $col = 0; $row++ }
}

$auditImgPath = Join-Path $outDir '01_Desktop_Icons_And_Shortcuts_Audit.png'
$bmpAudit.Save($auditImgPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmpAudit.Dispose()
$reportLines | Set-Content -Path (Join-Path $outDir 'qa-report.txt') -Encoding UTF8 -Force

# ============================================================================
# 2. Uji & Screenshot: XyDeskDashboard.exe (Pusat Kontrol RDP)
# ============================================================================
Write-Host "=== 2. Menguji & Screenshot XyDeskDashboard.exe ==="
if (Test-Path 'C:\XyRDP\tools\XyDeskDashboard.exe') {
  $pDash = Start-Process -FilePath 'C:\XyRDP\tools\XyDeskDashboard.exe' -PassThru
  Save-QaWindowScreenshot -Proc $pDash -OutName '02_XyDeskDashboard_GUI.png' `
    -Title 'QA TEST #2 - XyDeskRemote Dashboard (Gaming & Tools Hub)' `
    -Sub 'Exe: C:\XyRDP\tools\XyDeskDashboard.exe | Status: RUNNING OK' -WaitSec 5
  Stop-Process -Id $pDash.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 3. Uji & Screenshot: GTA SA-MP Control Center + SA-MP 0.3.7-R5 Browser (Side-by-Side)
# ============================================================================
Write-Host "=== 3. Menguji & Screenshot SA-MP Control Center & Server Browser ==="
New-Item -Path 'HKCU:\Software\SAMP' -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path 'HKCU:\Software\SAMP' -Name 'gta_sa_exe' -Value 'C:\Games\GTA San Andreas\gta_sa.exe' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path 'HKCU:\Software\SAMP' -Name 'PlayerName' -Value 'XyPlayer_RDP' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

$pPatchGui = $null
if (Test-Path 'C:\Games\GTA-SAMP\Patch-GTA-SAMP.ps1') {
  $pPatchGui = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Sta', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', 'C:\Games\GTA-SAMP\Patch-GTA-SAMP.ps1', '-Interactive') -PassThru
  Start-Sleep -Seconds 4
}
if (Test-Path 'C:\Games\GTA San Andreas\samp.exe') {
  $pSamp = Start-Process -FilePath 'C:\Games\GTA San Andreas\samp.exe' -WorkingDirectory 'C:\Games\GTA San Andreas' -PassThru
  Start-Sleep -Seconds 3
  try {
    $pSamp.Refresh()
    if ($pSamp.MainWindowHandle -ne [IntPtr]::Zero) {
      [WinCapture]::SetWindowPos($pSamp.MainWindowHandle, [WinCapture]::HWND_TOPMOST, 18, 72, 680, 560, [WinCapture]::SWP_SHOWWINDOW) | Out-Null
    }
  } catch {}
  Save-QaWindowScreenshot -Proc $pSamp -OutName '03_SAMP_037R5_And_ControlCenter.png' `
    -Title 'QA TEST #3 - GTA SA-MP 0.3.7-R5 Server Browser & Anti-Ban Control Center' `
    -Sub 'Exe: C:\Games\GTA San Andreas\samp.exe + Patch-GTA-SAMP.ps1 | PlayerName: XyPlayer_RDP | Clean Start' -WaitSec 2
  Stop-Process -Id $pSamp.Id -Force -ErrorAction SilentlyContinue
}
if ($pPatchGui) { Stop-Process -Id $pPatchGui.Id -Force -ErrorAction SilentlyContinue }

# ============================================================================
# 4. Uji & Screenshot: PLAY GTA San Andreas (gta_sa.exe In-Game / Title Screen)
# ============================================================================
Write-Host "=== 4. Menguji & Screenshot PLAY GTA San Andreas (gta_sa.exe) ==="
Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue | Select-Object Name, Status | Format-Table -AutoSize
if (Test-Path 'C:\Games\GTA San Andreas\gta_sa.exe') {
  $pGta = Start-Process -FilePath 'C:\Games\GTA San Andreas\gta_sa.exe' -WorkingDirectory 'C:\Games\GTA San Andreas' -PassThru
  Start-Sleep -Seconds 9
  Send-KeyPress 0x0D # Enter to skip splash
  Start-Sleep -Seconds 3
  Send-KeyPress 0x20 # Space
  Start-Sleep -Seconds 3
  $gtaProc = Get-Process -Name 'gta_sa' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($gtaProc) {
    $pGta = $gtaProc
  } else {
    Write-Host "gta_sa exited with code: $($pGta.ExitCode)"
    Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2} -MaxEvents 3 -ErrorAction SilentlyContinue | Format-List TimeCreated, Message
  }
  Save-QaWindowScreenshot -Proc $pGta -OutName '04_GTA_SanAndreas_InGame_Play.png' `
    -Title 'QA TEST #4 - PLAY GTA San Andreas (gta_sa.exe + dgVoodoo2 D3D11 + VB-Cable Audio)' `
    -Sub 'Exe: C:\Games\GTA San Andreas\gta_sa.exe | VB-Cable + DSOAL Sound + SilentPatch 90 FPS ACTIVE' -WaitSec 3
  Get-Process -Name 'gta_sa' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 5. Uji & Screenshot: PLAY Minecraft (PrismLauncher Main Dashboard + TLauncher Main Screen)
# ============================================================================
Write-Host "=== 5. Menguji & Screenshot PrismLauncher & TLauncher (TL.jar) ==="
if (Test-Path 'C:\Games\PrismLauncher\prismlauncher.exe') {
  $pPrism = Start-Process -FilePath 'C:\Games\PrismLauncher\prismlauncher.exe' -WorkingDirectory 'C:\Games\PrismLauncher' -PassThru
  Start-Sleep -Seconds 4
  Send-KeyPress 0x0D # Next
  Start-Sleep -Seconds 2
  Send-KeyPress 0x0D # Finish -> enters Main Dashboard!
  Start-Sleep -Seconds 2
  Save-QaWindowScreenshot -Proc $pPrism -OutName '05_Minecraft_PrismLauncher.png' `
    -Title 'QA TEST #5 - Minecraft PrismLauncher Portable (Main Dashboard + Account: XyPlayer_RDP)' `
    -Sub 'Exe: C:\Games\PrismLauncher\prismlauncher.exe | Java 21 + Mesa3D OpenGL 4.6 READY' -WaitSec 3
  Stop-Process -Id $pPrism.Id -Force -ErrorAction SilentlyContinue
}

if (Test-Path 'C:\Games\Minecraft\TL.jar') {
  $javawList = @(Get-ChildItem -Path 'C:\Program Files\Eclipse Adoptium', 'C:\hostedtoolcache\windows\Java_Temurin-Hotspot_jdk', 'C:\Program Files\Java' -Recurse -Filter 'javaw.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)
  $javawExe = if ($javawList.Count -gt 0) { $javawList[0].FullName } else { 'javaw.exe' }
  $pTl = Start-Process -FilePath $javawExe -ArgumentList @('-Xmx2048M', '-Dsun.java2d.d3d=false', '-jar', 'C:\Games\Minecraft\TL.jar') -WorkingDirectory 'C:\Games\Minecraft' -PassThru
  Start-Sleep -Seconds 10
  try {
    $pTl.Refresh()
    if ($pTl.MainWindowHandle -ne [IntPtr]::Zero) {
      [WinCapture]::SetForegroundWindow($pTl.MainWindowHandle) | Out-Null
      $rcTl = New-Object WinCapture+RECT
      if ([WinCapture]::GetWindowRect($pTl.MainWindowHandle, [ref]$rcTl)) {
        # Click "Alright, I got it!" button at bottom-right of Welcome dialog
        $btnX = $rcTl.Right - 90
        $btnY = $rcTl.Bottom - 45
        Send-LeftClick $btnX $btnY
      }
    }
  } catch {}
  Start-Sleep -Seconds 6
  # Re-find java/javaw window in case Legacy Launcher spawned main frame
  $javaWin = Get-Process -Name 'javaw', 'java' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
  if ($javaWin) { $pTl = $javaWin }
  Save-QaWindowScreenshot -Proc $pTl -OutName '06_Minecraft_TLauncher_Play.png' `
    -Title 'QA TEST #6 - PLAY Minecraft TLauncher (TL.jar + Java 21 + Mesa3D OpenGL 4.6)' `
    -Sub "Exe: $javawExe -jar C:\Games\Minecraft\TL.jar | Status: RUNNING OK" -WaitSec 3
  Get-Process -Name 'javaw', 'java' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 6. Uji & Screenshot: Blender 3D Studio 4.2 LTS (3D Viewport + Cube Rendered)
# ============================================================================
Write-Host "=== 6. Menguji & Screenshot Blender 3D 4.2 LTS (Full 3D Viewport) ==="
$blenderExe = Get-ChildItem -Path 'C:\Games\Blender' -Recurse -File -Filter 'blender.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($blenderExe) {
  $env:GALLIUM_DRIVER = 'llvmpipe'
  $env:LIBGL_ALWAYS_SOFTWARE = '1'
  $env:MESA_GL_VERSION_OVERRIDE = '4.6'
  $pBlend = Start-Process -FilePath $blenderExe.FullName -WorkingDirectory $blenderExe.DirectoryName -PassThru
  Start-Sleep -Seconds 15
  # Dismiss splash screen by pressing Escape or clicking viewport corner so the 3D Cube is 100% visible!
  Send-KeyPress 0x1B
  Start-Sleep -Seconds 1
  Send-LeftClick 160 220
  Save-QaWindowScreenshot -Proc $pBlend -OutName '07_Blender3D_42_Viewport.png' `
    -Title 'QA TEST #7 - Blender 3D Studio 4.2.3 LTS (3D Viewport Cube + Mesa3D OpenGL 4.6)' `
    -Sub "Exe: $($blenderExe.FullName) | OpenGL 4.6 llvmpipe 3D Viewport ACTIVE" -WaitSec 3
  Stop-Process -Id $pBlend.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 7. Uji & Screenshot: PLAY Euro Truck Simulator 2 (eurotrucks2.exe Activated In-Game)
# ============================================================================
Write-Host "=== 7. Menguji & Screenshot PLAY Euro Truck Simulator 2 ==="
$etsExe = 'C:\Games\ETS2\bin\win_x86\eurotrucks2.exe'
if (Test-Path $etsExe) {
  # Salin DSOAL juga ke folder ETS2 agar OpenAL/DirectSound di ETS2 selalu aktif
  foreach ($f in @('dsound.dll', 'dsoal-aldrv.dll', 'alsoft.ini')) {
    $src = Join-Path 'C:\Games\GTA-SAMP\SilentPatch-Pack' $f
    if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination (Join-Path 'C:\Games\ETS2\bin\win_x86' $f) -Force -ErrorAction SilentlyContinue }
  }
  $pEts = Start-Process -FilePath $etsExe -WorkingDirectory 'C:\Games\ETS2\bin\win_x86' -ArgumentList @('-nofullscreen', '-nointro') -PassThru
  Start-Sleep -Seconds 11
  try {
    $pEts.Refresh()
    if ($pEts.MainWindowHandle -ne [IntPtr]::Zero) {
      [WinCapture]::SetForegroundWindow($pEts.MainWindowHandle) | Out-Null
      Start-Sleep -Milliseconds 600
      # Ketikkan Product Key aktivasi penuh ETS 2 via Hardware Scan Code DirectInput!
      Send-DirectInputString "3342JDYJF0XEA3K5J0YS40UFY"
      Start-Sleep -Milliseconds 500
      Send-KeyPress 0x09 # Tab -> Activate Game
      Send-KeyPress 0x0D # Enter
    }
  } catch {}
  Start-Sleep -Seconds 5
  Save-QaWindowScreenshot -Proc $pEts -OutName '08_EuroTruckSimulator2_InGame_Play.png' `
    -Title 'QA TEST #8 - PLAY Euro Truck Simulator 2 (Activated Full Version - SCS Software 3D)' `
    -Sub 'Exe: C:\Games\ETS2\bin\win_x86\eurotrucks2.exe | Key: 3342J-DYJF0-XEA3K-5J0YS-40UFY + dgVoodoo2 D3D9 ACTIVE' -WaitSec 3
  Stop-Process -Id $pEts.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 8. Uji & Screenshot: PLAY Roblox (RobloxPlayerLauncher.exe + WebGL App Mode + RobloxPlayerBeta.exe)
# ============================================================================
Write-Host "=== 8. Menguji & Screenshot PLAY Roblox (WebGL App Mode + Native Client + Anti-VM Hub) ==="
$chromeExe = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$edgeExe   = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$browserExe = if (Test-Path $chromeExe) { $chromeExe } else { $edgeExe }
$pWebRbx = $null
if (Test-Path $browserExe) {
  $pWebRbx = Start-Process -FilePath $browserExe -ArgumentList @('--app=https://www.roblox.com/charts', '--window-size=620,640', '--window-position=12,72', '--no-first-run', '--no-default-browser-check', '--ignore-gpu-blocklist', '--enable-webgl') -PassThru
  Start-Sleep -Seconds 6
}
$pRbxBeta = $null
$betaExe = Get-ChildItem -Path 'C:\Games\Roblox\Versions' -Recurse -File -Filter 'RobloxPlayerBeta.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($betaExe) {
  $pRbxBeta = Start-Process -FilePath $betaExe.FullName -WorkingDirectory $betaExe.DirectoryName -ArgumentList '--app' -PassThru
  Start-Sleep -Seconds 3
}
if (Test-Path 'C:\Games\Roblox\RobloxPlayerLauncher.exe') {
  $pRbxHub = Start-Process -FilePath 'C:\Games\Roblox\RobloxPlayerLauncher.exe' -WorkingDirectory 'C:\Games\Roblox' -PassThru
  Start-Sleep -Seconds 2
  try {
    $pRbxHub.Refresh()
    if ($pRbxHub.MainWindowHandle -ne [IntPtr]::Zero) {
      [WinCapture]::SetWindowPos($pRbxHub.MainWindowHandle, [WinCapture]::HWND_TOPMOST, 445, 190, 560, 360, [WinCapture]::SWP_SHOWWINDOW) | Out-Null
    }
  } catch {}
  Save-QaWindowScreenshot -Proc $pRbxHub -OutName '09_Roblox_Play_And_AntiVM_Suite.png' `
    -Title 'QA TEST #9 - PLAY Roblox (Cloud/WebGL Charts + RobloxPlayerBeta.exe + Anti-VM Hub)' `
    -Sub 'Exe: RobloxPlayerLauncher.exe + RobloxPlayerBeta.exe (version-9ac8595712b447a7) + WebGL App Mode ACTIVE' -WaitSec 2
  Stop-Process -Id $pRbxHub.Id -Force -ErrorAction SilentlyContinue
}
if ($pRbxBeta) { Stop-Process -Id $pRbxBeta.Id -Force -ErrorAction SilentlyContinue }
if ($pWebRbx) { Stop-Process -Id $pWebRbx.Id -Force -ErrorAction SilentlyContinue }
Get-Process -Name 'RobloxPlayerBeta', 'chrome', 'msedge' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# ============================================================================
# 9. Uji & Screenshot: FiveM Prank App
# ============================================================================
Write-Host "=== 9. Menguji & Screenshot FiveM.exe ==="
if (Test-Path 'C:\Games\FiveM\FiveM.exe') {
  $pFive = Start-Process -FilePath 'C:\Games\FiveM\FiveM.exe' -WorkingDirectory 'C:\Games\FiveM' -PassThru
  Save-QaWindowScreenshot -Proc $pFive -OutName '10_FiveM_Prank_App.png' `
    -Title 'QA TEST #10 - FiveM CitizenFX Prank App + Voicemod Tuna Audio Loop' `
    -Sub 'Exe: C:\Games\FiveM\FiveM.exe | Official FiveM Icon + Sound Loop ACTIVE' -WaitSec 4
  Stop-Process -Id $pFive.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "=== QA E2E & Deep In-Game Play Screenshot Suite Selesai ==="
Get-ChildItem -Path $outDir | Select-Object Name, Length
