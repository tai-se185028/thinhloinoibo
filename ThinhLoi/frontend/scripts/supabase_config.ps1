function Get-PackFlowDefines {
  param([Parameter(Mandatory = $true)][string]$ProjectRoot)

  $localValues = @{}
  $localFile = Join-Path $ProjectRoot '.env.local'
  if (Test-Path -LiteralPath $localFile) {
    foreach ($line in Get-Content -LiteralPath $localFile -Encoding UTF8) {
      if ($line -match '^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
        $name = $Matches[1]
        $value = $Matches[2]
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
          $value = $value.Substring(1, $value.Length - 2)
        }
        $localValues[$name] = $value
      }
    }
  }

  $resolvedValues = @{}
  foreach ($name in @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) { $value = [Environment]::GetEnvironmentVariable("NEXT_PUBLIC_$name") }
    if ([string]::IsNullOrWhiteSpace($value)) { $value = $localValues[$name] }
    if ([string]::IsNullOrWhiteSpace($value)) { $value = $localValues["NEXT_PUBLIC_$name"] }
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing $name. Configure PowerShell environment variables or frontend/.env.local." }
    $resolvedValues[$name] = $value.Trim()
  }

  $uri = $null
  if (-not [Uri]::TryCreate($resolvedValues['SUPABASE_URL'], [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
    throw 'SUPABASE_URL must be a valid HTTPS URL.'
  }
  if ($resolvedValues['SUPABASE_PUBLISHABLE_KEY'].StartsWith('sb_secret_')) {
    throw 'Secret keys cannot be used in Flutter. Use a publishable key.'
  }
  foreach ($name in @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')) {
    "--dart-define=$name=$($resolvedValues[$name])"
  }
}
