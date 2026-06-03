# Buildkite may select hooks/post-command.ps1 on Windows agents. Logic lives in hooks/post-command (Bash).
$ErrorActionPreference = 'Stop'
$HookDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginRoot = (Resolve-Path (Join-Path $HookDir '..')).Path
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
  Write-Error 'endorlabs plugin: bash is required on Windows (Git for Windows / Git Bash). See README.'
  exit 1
}
Set-Location $PluginRoot
& bash (Join-Path $HookDir 'post-command') @args
exit $LASTEXITCODE
