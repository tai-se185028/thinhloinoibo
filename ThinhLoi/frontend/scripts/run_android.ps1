param([switch]$CheckConfiguration)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'supabase_config.ps1')
$flutterDefines = @(Get-PackFlowDefines -ProjectRoot $projectRoot)
if ($CheckConfiguration) { Write-Output 'Supabase configuration is valid. No configuration values were printed.'; return }
Push-Location $projectRoot
try {
  flutter run @flutterDefines
} finally { Pop-Location }
