# Maintainer-only: run a local Phase 7 scenario via docker-compose.phase7-local.yml.
# Does not print secret values. Requires Docker Desktop.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('baseline', 'ai-models', 'soft-fail', 'container')]
    [string]$Scenario
)

$ErrorActionPreference = 'Stop'
$contribDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$plugin = if ($env:PHASE7_PLUGIN_DIR) { $env:PHASE7_PLUGIN_DIR } else {
    (Resolve-Path (Join-Path $contribDir '../..')).Path
}
if (-not $env:PHASE7_WORK_DIR) {
    Write-Error 'Set PHASE7_WORK_DIR to the absolute path of the target git checkout.'
}
$work = $env:PHASE7_WORK_DIR
$allow = @('ENDOR_API', 'ENDOR_API_CREDENTIALS_KEY', 'ENDOR_API_CREDENTIALS_SECRET', 'ENDOR_NAMESPACE')
$envFile = Join-Path $plugin '.env'
if (-not (Test-Path $envFile)) {
    Write-Error "Missing .env at $envFile (gitignored; create locally for maintainer smoke tests)."
}
$trimmed = Join-Path $env:TEMP 'phase7-trimmed.env'
$lines = Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        $k = $matches[1]
        if ($allow -contains $k) { "$k=$($matches[2].Trim())" }
    }
}
[System.IO.File]::WriteAllText($trimmed, ($lines -join "`n") + "`n")
$env:PHASE7_PLUGIN_DIR = ($plugin -replace '\\', '/')
$env:PHASE7_WORK_DIR = ($work -replace '\\', '/')
$env:PHASE7_ENV_FILE = ($trimmed -replace '\\', '/')
$ns = ((Get-Content $trimmed | Where-Object { $_ -match '^ENDOR_NAMESPACE=' } | Select-Object -First 1) -replace '^ENDOR_NAMESPACE=', '').Trim()

$logDir = Join-Path $plugin '.phase7-logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir "$Scenario-docker.log"

$composeFile = Join-Path $contribDir 'docker-compose.phase7-local.yml'
$pluginEnv = @{
    'BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE'             = $ns
    'BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV'           = 'ENDOR_API_CREDENTIALS_KEY'
    'BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV'        = 'ENDOR_API_CREDENTIALS_SECRET'
    'BUILDKITE_PLUGIN_ENDORLABS_SCAN_PATH'             = '.'
    'BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE'              = 'true'
    'BUILDKITE_PLUGIN_ENDORLABS_ADDITIONAL_ARGS'       = '--bypass-host-check'
    'BUILDKITE_BRANCH'                                 = 'local-phase7'
}

switch ($Scenario) {
    'baseline' {
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE'] = 'endor-local-deps-tools.json'
    }
    'ai-models' {
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_AI_MODELS'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE'] = 'endor-local-ai-models.json'
    }
    'soft-fail' {
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE'] = 'endor-local-soft-fail.json'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SOFT_FAIL'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_FAIL_ON_POLICY'] = 'false'
    }
    'container' {
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER'] = 'true'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES'] = 'false'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_IMAGE'] = 'alpine:3.19'
        $pluginEnv['BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE'] = 'endor-local-container.json'
    }
}

$dockerArgs = @('compose', '-f', $composeFile, 'run', '--rm')
foreach ($kv in $pluginEnv.GetEnumerator()) {
    $dockerArgs += @('-e', "$($kv.Key)=$($kv.Value)")
}
if ($Scenario -eq 'container') {
    $dockerArgs += @('-v', '/var/run/docker.sock:/var/run/docker.sock')
}
$dockerArgs += @(
    'phase7',
    'set -a && . /run/secrets/endor.env && set +a && export PATH=/usr/local/bin:$PATH && cd /work && bash /plugin/hooks/post-command'
)

Write-Host "phase7: scenario=$Scenario log=$log"
& docker @dockerArgs 2>&1 | Tee-Object -FilePath $log
Write-Host "phase7: hook exit=$LASTEXITCODE"
exit $LASTEXITCODE
