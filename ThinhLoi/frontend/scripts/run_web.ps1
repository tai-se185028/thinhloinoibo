param(
  [switch]$CheckConfiguration,
  [int]$Port = 3000
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot 'supabase_config.ps1')
$flutterDefines = @(Get-PackFlowDefines -ProjectRoot $projectRoot)
if ($CheckConfiguration) { Write-Output 'Supabase configuration is valid. No configuration values were printed.'; return }

$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($listener) {
  $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
  $ownerName = if ($owner) { $owner.ProcessName } else { 'unknown' }
  throw "Port $Port is already in use by PID $($listener.OwningProcess) ($ownerName). Stop it with: Stop-Process -Id $($listener.OwningProcess). Or run this script with -Port 3001."
}

Push-Location $projectRoot
try {
  flutter run -d chrome --web-port $Port @flutterDefines
} finally {
  Pop-Location
}
