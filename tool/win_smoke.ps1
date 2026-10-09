# يشغل التطبيق ويتأكد إنه فتح شباك ظاهر وما وقع.
param([string]$exe, [string]$label)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h); }
"@
Remove-Item "$env:TEMP\ReelsMaker-crash.txt" -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $exe -PassThru
Start-Sleep -Seconds 30
$p.Refresh()
if ($p.HasExited) {
  echo "::notice::[$label] EXE EXITED code=$($p.ExitCode)"
} else {
  $h = $p.MainWindowHandle
  echo "::notice::[$label] alive after 30s, window=$h visible=$([W]::IsWindowVisible($h)) title='$($p.MainWindowTitle)' mem=$([int]($p.WorkingSet64/1MB))MB"
  Stop-Process -Id $p.Id -Force
}
$crash = "$env:TEMP\ReelsMaker-crash.txt"
if (Test-Path $crash) { echo "::notice::[$label] crash: $((Get-Content $crash -Raw) -replace '\s+',' ' | Select-Object -First 1)" }
$ev = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=(Get-Date).AddMinutes(-2)} -ErrorAction SilentlyContinue | Select-Object -First 2
foreach ($e in $ev) { $m = $e.Message -replace '\s+',' '; echo "::notice::[$label] EVENT $($e.ProviderName): $($m.Substring(0, [Math]::Min(300, $m.Length)))" }
