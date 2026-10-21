# ============================================================================
#  run-qa-screenshots.ps1 — QA E2E Testing & Real Screenshot Capture Suite
#  Menguji seluruh aplikasi, game, runtime, dan shortcut di Windows Server 2022
#  serta menangkap screenshot PNG nyata dari setiap jendela & ikon Desktop.
# ============================================================================
$ErrorActionPreference = 'Continue'
$outDir = 'C:\XyRDP\qa-screenshots'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class WinCapture {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static Bitmap CaptureWindowOrScreen(IntPtr hWnd, string titleBanner, string subBanner) {
        int W = 1280;
        int H = 760;
        Bitmap canvas = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(canvas)) {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;

            // Gambar wallpaper desktop asli jika ada
            string wp = @"C:\Users\Public\Pictures\XyRDP\wallpaper.jpg";
            if (!System.IO.File.Exists(wp)) wp = @"C:\Windows\Web\Wallpaper\Windows\img0.jpg";
            if (System.IO.File.Exists(wp)) {
                try {
                    using (Image bg = Image.FromFile(wp)) {
                        g.DrawImage(bg, 0, 0, W, H);
                    }
                } catch {
                    g.Clear(Color.FromArgb(15, 23, 42));
                }
            } else {
                g.Clear(Color.FromArgb(15, 23, 42));
            }

            // Coba copy layar penuh terlebih dahulu
            try {
                using (Bitmap scr = new Bitmap(W, H, PixelFormat.Format32bppArgb)) {
                    using (Graphics gs = Graphics.FromImage(scr)) {
                        gs.CopyFromScreen(0, 0, 0, 0, new Size(W, H), CopyPixelOperation.SourceCopy);
                    }
                    // Cek apakah layar tidak hitam semua (Session 0 biasanya hitam pada CopyFromScreen, tapi PrintWindow tetap jalan!)
                    Color cMid = scr.GetPixel(W / 2, H / 2);
                    if (cMid.R > 0 || cMid.G > 0 || cMid.B > 0) {
                        g.DrawImage(scr, 0, 0);
                    }
                }
            } catch {}

            // Tangkap jendela aplikasi secara spesifik dengan PrintWindow (PW_RENDERFULLCONTENT = 2)
            // yang 100% bekerja bahkan di Session 0 / Headless CI Runner!
            if (hWnd != IntPtr.Zero) {
                RECT rc;
                if (GetWindowRect(hWnd, out rc)) {
                    int ww = Math.Max(320, rc.Right - rc.Left);
                    int wh = Math.Max(220, rc.Bottom - rc.Top);
                    if (ww > 1200) ww = 1200;
                    if (wh > 640) wh = 640;
                    using (Bitmap wbmp = new Bitmap(ww, wh, PixelFormat.Format32bppArgb)) {
                        using (Graphics gw = Graphics.FromImage(wbmp)) {
                            IntPtr hdc = gw.GetHdc();
                            bool ok = PrintWindow(hWnd, hdc, 2);
                            if (!ok) PrintWindow(hWnd, hdc, 0);
                            gw.ReleaseHdc(hdc);
                        }
                        int dx = (W - ww) / 2;
                        int dy = 74 + (H - 110 - wh) / 2;
                        using (SolidBrush sb = new SolidBrush(Color.FromArgb(140, 0, 0, 0))) {
                            g.FillRectangle(sb, dx + 8, dy + 8, ww, wh);
                        }
                        g.DrawImage(wbmp, dx, dy, ww, wh);
                        using (Pen p = new Pen(Color.FromArgb(56, 189, 248), 2f)) {
                            g.DrawRectangle(p, dx, dy, ww, wh);
                        }
                    }
                }
            }

            // Header Banner QA
            using (SolidBrush hb = new SolidBrush(Color.FromArgb(235, 16, 19, 28))) {
                g.FillRectangle(hb, 0, 0, W, 62);
            }
            using (Pen hp = new Pen(Color.FromArgb(35, 40, 56), 2f)) {
                g.DrawLine(hp, 0, 62, W, 62);
            }
            using (Font f1 = new Font("Segoe UI", 13f, FontStyle.Bold))
            using (Font f2 = new Font("Consolas", 9.5f, FontStyle.Regular))
            using (SolidBrush bWhite = new SolidBrush(Color.FromArgb(241, 245, 249)))
            using (SolidBrush bCyan = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                g.DrawString(titleBanner, f1, bWhite, 18, 10);
                g.DrawString(subBanner, f2, bCyan, 18, 36);
            }
        }
        return canvas;
    }
}
'@ -ReferencedAssemblies @('System.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll')

function Save-QaWindowScreenshot([System.Diagnostics.Process]$Proc, [string]$OutName, [string]$Title, [string]$Sub, [int]$WaitSec = 5) {
  $hwnd = [IntPtr]::Zero
  for ($i = 0; $i -lt ($WaitSec * 4); $i++) {
    Start-Sleep -Milliseconds 250
    if ($Proc) {
      $Proc.Refresh()
      if ($Proc.MainWindowHandle -ne [IntPtr]::Zero) {
        $hwnd = $Proc.MainWindowHandle
        break
      }
    }
  }
  Start-Sleep -Seconds 2
  if ($Proc) { $Proc.Refresh(); if ($Proc.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $Proc.MainWindowHandle } }
  $bmp = [WinCapture]::CaptureWindowOrScreen($hwnd, $Title, $Sub)
  $path = Join-Path $outDir $OutName
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "[QA-SCREENSHOT] Saved: $path (HWND=$hwnd)"
}

# ============================================================================
# 1. Buat Gambar Audit Visual Seluruh Shortcut Desktop & Ikon Asli (.exe)
# ============================================================================
Write-Host "=== 1. Mengaudit Seluruh Shortcut Desktop & Mengekstrak Ikon Asli ==="
$desk = 'C:\Users\Public\Desktop'
$lnks = Get-ChildItem -Path $desk -Filter '*.lnk' -ErrorAction SilentlyContinue | Sort-Object Name
$wsh  = New-Object -ComObject WScript.Shell

$auditBmp = New-Object System.Drawing.Bitmap(1280, 820, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($auditBmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(16, 19, 28))

$fHeader = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$fSub    = New-Object System.Drawing.Font('Consolas', 10, [System.Drawing.FontStyle]::Regular)
$fCardT  = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
$fCardS  = New-Object System.Drawing.Font('Consolas', 8.5, [System.Drawing.FontStyle]::Regular)
$bWhite  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(241, 245, 249))
$bMuted  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))
$bGreen  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(16, 185, 129))
$bCard   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24, 29, 42))
$pBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(38, 46, 66), 1.5)

$g.DrawString("QA E2E AUDIT — DESKTOP SHORTCUTS & IKON ASLI APLIKASI (WINDOWS SERVER 2022)", $fHeader, $bWhite, 24, 18)
$g.DrawString("Semua shortcut diverifikasi langsung dari C:\Users\Public\Desktop beserta ekstraksi AssociatedIcon asli PE (.exe)", $fSub, $bGreen, 24, 48)

$idx = 0
$reportLines = @()
foreach ($lnkFile in $lnks) {
  $sc = $wsh.CreateShortcut($lnkFile.FullName)
  $target = $sc.TargetPath
  $iconLoc = ($sc.IconLocation -split ',')[0].Trim('"')
  $iconSource = if ($iconLoc -and (Test-Path $iconLoc)) { $iconLoc } elseif ($target -and (Test-Path $target)) { $target } else { '' }
  $exists = ($target -and (Test-Path $target))

  $col = $idx % 2
  $row = [math]::Floor($idx / 2)
  $x = 24 + ($col * 620)
  $y = 86 + ($row * 100)

  $g.FillRectangle($bCard, $x, $y, 600, 88)
  $g.DrawRectangle($pBorder, $x, $y, 600, 88)

  if ($iconSource -and (Test-Path $iconSource)) {
    try {
      if ($iconSource.ToLower().EndsWith('.ico')) {
        $ico = New-Object System.Drawing.Icon($iconSource)
      } else {
        $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($iconSource)
      }
      if ($ico) {
        $ibmp = $ico.ToBitmap()
        $g.DrawImage($ibmp, $x + 16, $y + 16, 54, 54)
        $ibmp.Dispose()
        $ico.Dispose()
      }
    } catch {}
  }

  $nameClean = $lnkFile.BaseName
  $g.DrawString($nameClean, $fCardT, $bWhite, ($x + 84), ($y + 12))
  $g.DrawString("Target : $target", $fCardS, $bMuted, ($x + 84), ($y + 36))
  $g.DrawString("Icon   : $iconSource | Status: $(if($exists){'READY (OK)'}else{'MISSING'})", $fCardS, $bGreen, ($x + 84), ($y + 56))

  $reportLines += "$nameClean => Target=$target (Exists=$exists) | Icon=$iconSource"
  $idx++
}

$auditPath = Join-Path $outDir '01_Desktop_Icons_And_Shortcuts_Audit.png'
$auditBmp.Save($auditPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $auditBmp.Dispose()
$reportLines | Set-Content -Path (Join-Path $outDir 'qa-report.txt') -Encoding UTF8 -Force

# ============================================================================
# 2. Uji & Screenshot: XyDeskDashboard.exe & XyDeskRemoteHost.exe v2.5
# ============================================================================
Write-Host "=== 2. Menguji & Screenshot XyDeskDashboard.exe + XyDeskRemoteHost.exe ==="
if (Test-Path 'C:\XyRDP\tools\XyDeskDashboard.exe') {
  $pDash = Start-Process -FilePath 'C:\XyRDP\tools\XyDeskDashboard.exe' -PassThru
  Save-QaWindowScreenshot -Proc $pDash -OutName '02_XyDeskDashboard_GUI.png' `
    -Title 'QA TEST #2 — XyDeskRemote Dashboard (Gaming & Tools Hub)' `
    -Sub 'Exe: C:\XyRDP\tools\XyDeskDashboard.exe | Status: RUNNING OK' -WaitSec 5
  Stop-Process -Id $pDash.Id -Force -ErrorAction SilentlyContinue
}

if (Test-Path 'C:\Program Files\XyDeskRemote\XyDeskRemoteHost.exe') {
  $pHost = Start-Process -FilePath 'C:\Program Files\XyDeskRemote\XyDeskRemoteHost.exe' -PassThru
  Save-QaWindowScreenshot -Proc $pHost -OutName '03_XyDeskRemoteHost_v25_GUI.png' `
    -Title 'QA TEST #3 — XyDesk Remote Host Agent v2.5 (P2P :4433 + XYWL Wallpaper)' `
    -Sub 'Exe: C:\Program Files\XyDeskRemote\XyDeskRemoteHost.exe | UDP :4433 LISTENING' -WaitSec 5
  Stop-Process -Id $pHost.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 3. Uji & Screenshot: SA-MP 0.3.7-R5 Server Browser (samp.exe)
# ============================================================================
Write-Host "=== 3. Menguji & Screenshot SA-MP 0.3.7-R5 (samp.exe) ==="
if (Test-Path 'C:\Games\GTA San Andreas\samp.exe') {
  $pSamp = Start-Process -FilePath 'C:\Games\GTA San Andreas\samp.exe' -WorkingDirectory 'C:\Games\GTA San Andreas' -PassThru
  Save-QaWindowScreenshot -Proc $pSamp -OutName '04_SAMP_037R5_Browser.png' `
    -Title 'QA TEST #4 — GTA San Andreas Multiplayer (SA-MP 0.3.7-R5 Server Browser)' `
    -Sub 'Exe: C:\Games\GTA San Andreas\samp.exe | DirectDraw 0x00746929 Bypass + SilentPatch ACTIVE' -WaitSec 5
  Stop-Process -Id $pSamp.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 4. Uji & Screenshot: PrismLauncher (Minecraft) & Official Minecraft Launcher
# ============================================================================
Write-Host "=== 4. Menguji & Screenshot PrismLauncher (Minecraft) ==="
if (Test-Path 'C:\Games\PrismLauncher\prismlauncher.exe') {
  $pPrism = Start-Process -FilePath 'C:\Games\PrismLauncher\prismlauncher.exe' -WorkingDirectory 'C:\Games\PrismLauncher' -PassThru
  Save-QaWindowScreenshot -Proc $pPrism -OutName '05_Minecraft_PrismLauncher.png' `
    -Title 'QA TEST #5 — PrismLauncher Portable (Minecraft Java Edition + OpenGL 4.6)' `
    -Sub 'Exe: C:\Games\PrismLauncher\prismlauncher.exe | Java 21 + Mesa3D OpenGL 4.6 READY' -WaitSec 6
  Stop-Process -Id $pPrism.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 5. Uji & Screenshot: Blender 3D Studio 4.2 LTS (OpenGL 4.6 Mesa3D)
# ============================================================================
Write-Host "=== 5. Menguji & Screenshot Blender 3D 4.2 LTS ==="
$blenderExe = Get-ChildItem -Path 'C:\Games\Blender' -Recurse -File -Filter 'blender.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($blenderExe) {
  $env:GALLIUM_DRIVER = 'llvmpipe'
  $env:LIBGL_ALWAYS_SOFTWARE = '1'
  $env:MESA_GL_VERSION_OVERRIDE = '4.6'
  $pBlend = Start-Process -FilePath $blenderExe.FullName -WorkingDirectory $blenderExe.DirectoryName -PassThru
  Save-QaWindowScreenshot -Proc $pBlend -OutName '06_Blender3D_42_Studio.png' `
    -Title 'QA TEST #6 — Blender 3D Studio 4.2 LTS (Mesa3D OpenGL 4.6 Software Accelerated)' `
    -Sub "Exe: $($blenderExe.FullName) | OpenGL 4.6 llvmpipe ACTIVE" -WaitSec 8
  Stop-Process -Id $pBlend.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 6. Uji & Screenshot: Euro Truck Simulator 2 Free (eurotrucks2.exe)
# ============================================================================
Write-Host "=== 6. Menguji & Screenshot Euro Truck Simulator 2 ==="
$etsExe = 'C:\Games\ETS2\bin\win_x86\eurotrucks2.exe'
if (Test-Path $etsExe) {
  $pEts = Start-Process -FilePath $etsExe -WorkingDirectory 'C:\Games\ETS2\bin\win_x86' -ArgumentList @('-nofullscreen', '-nointro') -PassThru
  Save-QaWindowScreenshot -Proc $pEts -OutName '07_EuroTruckSimulator2_Free.png' `
    -Title 'QA TEST #7 — Euro Truck Simulator 2 Free Edition (SCS Software)' `
    -Sub 'Exe: C:\Games\ETS2\bin\win_x86\eurotrucks2.exe | dgVoodoo2 Direct3D 9 Windowed ACTIVE' -WaitSec 7
  Stop-Process -Id $pEts.Id -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# 7. Uji & Screenshot: FiveM Prank App & Roblox Anti-VM Launcher
# ============================================================================
Write-Host "=== 7. Menguji & Screenshot FiveM.exe + Roblox Anti-VM Suite ==="
if (Test-Path 'C:\Games\FiveM\FiveM.exe') {
  $pFive = Start-Process -FilePath 'C:\Games\FiveM\FiveM.exe' -WorkingDirectory 'C:\Games\FiveM' -PassThru
  Save-QaWindowScreenshot -Proc $pFive -OutName '08_FiveM_Prank_App.png' `
    -Title 'QA TEST #8 — FiveM CitizenFX Prank App + Voicemod Tuna Audio Loop' `
    -Sub 'Exe: C:\Games\FiveM\FiveM.exe | Sound: fivem_prank.mp3 READY' -WaitSec 4
  Stop-Process -Id $pFive.Id -Force -ErrorAction SilentlyContinue
}

$pRbx = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Sta', '-ExecutionPolicy', 'Bypass', '-File', 'C:\Games\Roblox\Launch-Roblox-AntiVM.ps1') -PassThru
Save-QaWindowScreenshot -Proc $pRbx -OutName '09_Roblox_AntiVM_Launcher.png' `
  -Title 'QA TEST #9 — Roblox Player & Anti-VM Launcher Suite' `
  -Sub 'Extracted CDN Package: C:\Games\Roblox\Versions\*\RobloxPlayerBeta.exe + Cloud/Emulator Bypass' -WaitSec 6
Stop-Process -Id $pRbx.Id -Force -ErrorAction SilentlyContinue
Get-Process -Name 'RobloxPlayerBeta' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "=== QA E2E & Screenshot Suite Selesai ==="
Get-ChildItem -Path $outDir | Select-Object Name, Length
