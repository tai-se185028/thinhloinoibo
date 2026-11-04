param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot

Push-Location $backendRoot
try {
  Write-Output 'Checking local and remote migration versions...'
  npx supabase migration list --remote
  if ($LASTEXITCODE -ne 0) { throw 'Could not read remote migration status.' }

  Write-Output 'Running production migration dry-run...'
  npx supabase db push --remote --dry-run
  if ($LASTEXITCODE -ne 0) { throw 'Supabase migration dry-run failed.' }

  if (-not $Apply) {
    Write-Output 'Dry-run complete. Use -Apply to apply pending non-destructive migrations.'
    return
  }

  Write-Output 'Applying pending migrations to the linked Supabase project...'
  npx supabase db push --remote --yes
  if ($LASTEXITCODE -ne 0) { throw 'Supabase migration apply failed.' }

  Write-Output 'Verifying remote migration versions...'
  npx supabase migration list --remote
  if ($LASTEXITCODE -ne 0) { throw 'Could not verify remote migration status.' }
} finally {
  Pop-Location
}
