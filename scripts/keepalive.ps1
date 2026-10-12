# RdpFree session lifetime uses the published expiry, not a fresh full duration after setup.
$XyTag='RdpFree:session'
. "$PSScriptRoot/lib-common.ps1"
$st=Read-Status
if (-not $st -or -not $st.expires_at) { throw 'Status sesi tidak memiliki expires_at' }
$stop=[DateTimeOffset]::Parse($st.expires_at).UtcDateTime.AddMinutes(-2)
$ip=$st.akses.tailscale.ip
Write-Host '::group::SUDAH ONLINE — koneksi privat'
Log "Alamat   : $ip`:3389"
Log "Username : $($st.rdp_user)"
Log 'Password : lihat/salin di dashboard terlindungi; tidak ditulis ke log publik.'
Log "Berakhir : $($st.expires_at) UTC"
Log 'Jika desktop hitam tetapi pointer terlihat: Ctrl+Alt+End > Task Manager > Run new task > explorer.exe.'
Write-Host '::endgroup::'
if($env:GITHUB_STEP_SUMMARY){
  @"
## SUDAH ONLINE
| Koneksi | Nilai |
| --- | --- |
| Host | $ip`:3389 |
| Username | $($st.rdp_user) |
| Password | Buka dashboard terlindungi; tidak dipublikasikan |
| Berakhir (UTC) | $($st.expires_at) |

Koneksi privat siap bukan bukti semua game telah berhasil dijalankan.
"@ | Out-File -Append -Encoding utf8 $env:GITHUB_STEP_SUMMARY
}
$nextPublish=(Get-Date).ToUniversalTime().AddMinutes(5)
while ((Get-Date).ToUniversalTime() -lt $stop) {
  $left=$stop-(Get-Date).ToUniversalTime()
  Log "SUDAH ONLINE | sisa $($left.ToString('hh\:mm'))"
  if ((Get-Date).ToUniversalTime() -ge $nextPublish) {
    Update-Status @{heartbeat_at=(Get-Date).ToUniversalTime().ToString('o')} | Out-Null
    & "$PSScriptRoot/publish-status.ps1" -Active $true
    $nextPublish=(Get-Date).ToUniversalTime().AddMinutes(5)
  }
  Start-Sleep -Seconds ([int][Math]::Max(1,[Math]::Min(60,$left.TotalSeconds)))
}
Log 'Durasi selesai; lanjut finalize.'
