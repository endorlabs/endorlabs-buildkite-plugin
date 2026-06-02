# Trigger repro-sandbox Buildkite build with env from .env (local maintainer helper).
param(
  [string]$EnvFile = "$PSScriptRoot\..\.env",
  [string]$Org = "tim-gowan",
  [string]$Pipeline = "repro-sandbox",
  [string]$Branch = "dev"
)

Get-Content $EnvFile | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
    Set-Item -Path "Env:$($matches[1])" -Value $matches[2].Trim().Trim('"').Trim("'")
  }
}

if (-not $env:BUILDKITE_API_TOKEN) { throw "BUILDKITE_API_TOKEN missing in $EnvFile" }
if (-not $env:ENDOR_NAMESPACE) { throw "ENDOR_NAMESPACE missing in $EnvFile" }

$headers = @{
  Authorization = "Bearer $env:BUILDKITE_API_TOKEN"
  "Content-Type" = "application/json"
}

$buildEnv = @{
  ENDOR_NAMESPACE = $env:ENDOR_NAMESPACE
  ENDORLABS_BUILDKITE_PLUGIN_SPEC = "https://github.com/endorlabs/endorlabs-buildkite-plugin.git#main"
  ENDOR_API_CREDENTIALS_KEY = $env:ENDOR_API_CREDENTIALS_KEY
  ENDOR_API_CREDENTIALS_SECRET = $env:ENDOR_API_CREDENTIALS_SECRET
}

$body = @{
  commit = "HEAD"
  branch = $Branch
  message = "Maintainer trigger with full env"
  env = $buildEnv
} | ConvertTo-Json -Depth 4

$r = Invoke-RestMethod -Method POST -Uri "https://api.buildkite.com/v2/organizations/$Org/pipelines/$Pipeline/builds" -Headers $headers -Body $body
Write-Output "Build #$($r.number) $($r.state) $($r.web_url)"
