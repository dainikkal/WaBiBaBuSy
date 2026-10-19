# LAN pre-flight for a Windows machine: why might WaBiBaBuSy not start or not connect here?
#   powershell -ExecutionPolicy Bypass -File tools\check-machine.ps1 [-Port 50051]
# Read-only: it only reports, it changes nothing.
param([int]$Port = 50051)

$warnings = 0
function Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow; $script:warnings++ }
function Info($msg) { Write-Host "       $msg" }

# 1. Smart App Control: blocks unsigned DLLs (Avalonia, Vortice, ...) -> the app dies without a window
$sac = $null
try { $sac = (Get-MpComputerStatus -ErrorAction Stop).SmartAppControlState } catch { }
if (-not $sac) {
    $raw = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState
    $sac = switch ($raw) { 0 { 'Off' } 1 { 'On' } 2 { 'Eval' } default { 'NotAvailable' } }
}
switch ($sac) {
    'On'   { Warn "Smart App Control is ON - it will block WaBiBaBuSy's unsigned DLLs."
             Info "Fix: Windows Security > App & browser control > Smart App Control settings > Off" }
    'Eval' { Warn "Smart App Control is in EVALUATION - Windows may switch it On and start blocking."
             Info "Turn it Off to be safe: Windows Security > App & browser control > Smart App Control settings" }
    default { Ok "Smart App Control: $sac" }
}

# 2. Recent Code Integrity blocks (Smart App Control or an admin WDAC policy)
try {
    $blocks = Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -MaxEvents 200 -ErrorAction Stop |
        Where-Object { $_.Id -in 3033, 3077, 3089 -and $_.Message -match 'WaBiBaBuSy|Avalonia|Vortice|Magick|LibVLC' } |
        Select-Object -First 3
    if ($blocks) {
        Warn "Windows blocked WaBiBaBuSy files recently:"
        $blocks | ForEach-Object { Info ("{0:g}  {1}" -f $_.TimeCreated, ($_.Message -split "`n")[0]) }
    } else { Ok "No recent Code Integrity blocks of WaBiBaBuSy files" }
} catch { Info "Code Integrity log not readable (run as admin for this check)" }

# 3. Startup crashes recorded by .NET
$crash = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = '.NET Runtime'; StartTime = (Get-Date).AddDays(-2) } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'WaBiBaBuSy' } | Select-Object -First 1
if ($crash) {
    Warn ("WaBiBaBuSy crashed at {0:g}:" -f $crash.TimeCreated)
    Info (($crash.Message -split "`n" | Where-Object { $_ -match 'Exception Info|Could not load|blocked' }) -join ' ')
} else { Ok "No WaBiBaBuSy crashes in the last 2 days" }

# 4. .NET 9 runtimes (Desktop for the UI, ASP.NET Core for the gRPC server)
$runtimes = & dotnet --list-runtimes 2>$null
foreach ($fx in 'Microsoft.WindowsDesktop.App 9.', 'Microsoft.AspNetCore.App 9.') {
    if ($runtimes -match [regex]::Escape($fx)) { Ok "$($fx.TrimEnd('.')) runtime installed" }
    else { Warn "$($fx.TrimEnd('.')) runtime missing - install the .NET 9 Desktop + ASP.NET Core runtimes (or the SDK)" }
}

# 5. Already running / port in use
$procs = Get-Process | Where-Object Name -like 'WaBiBaBuSy*'
if ($procs) { Info ("Running: " + (($procs | ForEach-Object { "$($_.Name) ($($_.Id))" }) -join ', ')) }
else { Info "WaBiBaBuSy is not running" }
$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
    $owner = (Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue).Name
    if ($owner -like 'WaBiBaBuSy*') { Ok "Port $Port is served by $owner (server running)" }
    else { Warn "Port $Port is taken by '$owner' - the WaBiBaBuSy server cannot start" }
} else { Info "Nothing listens on port $Port (fine unless this machine should be the server)" }

# 6. Startup log written by the app itself
$log = Join-Path $env:LOCALAPPDATA 'WaBiBaBuSy\Logs\startup.log'
if (Test-Path $log) {
    Info "Last startup log lines ($log):"
    Get-Content $log -Tail 3 | ForEach-Object { Info "  $_" }
}

Write-Host ""
if ($warnings -eq 0) { Write-Host "All checks passed." -ForegroundColor Green }
else { Write-Host "$warnings warning(s) - see above." -ForegroundColor Yellow }
