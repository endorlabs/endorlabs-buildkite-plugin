# Maintainer-only: local endorctl smoke tests

These scripts are **optional** for plugin maintainers. They are not required to
use the [Endor Labs Buildkite plugin](https://github.com/endorlabs/endorlabs-buildkite-plugin)
in production pipelines.

They run `hooks/post-command` with a real `endorctl` binary inside a Linux
container, mounting a local git checkout and credentials from a **gitignored**
`.env` at the repository root.

## Prerequisites

- Docker (Docker Desktop on Windows/macOS)
- A `.env` file with `ENDOR_API`, `ENDOR_API_CREDENTIALS_KEY`,
  `ENDOR_API_CREDENTIALS_SECRET`, and `ENDOR_NAMESPACE` (do not commit `.env`)
- `PHASE7_WORK_DIR` pointing at a git checkout (for example OWASP Juice Shop)

Do not set `ENDOR_TOKEN` in the same environment as API credentials; endorctl
returns exit code 4 for conflicting auth.

## Usage

From the **repository root**:

```bash
export PHASE7_WORK_DIR=/path/to/your/checkout
bash contrib/phase7-local/local-juice-shop.sh baseline
```

```powershell
$env:PHASE7_PLUGIN_DIR = (Get-Location).Path -replace '\\', '/'
$env:PHASE7_WORK_DIR = "/path/to/your/checkout"
./contrib/phase7-local/run-phase7-docker.ps1 -Scenario baseline
```

Scenarios: `baseline`, `ai-models`, `soft-fail`, `container` (container needs Docker socket).

Logs are written under `.phase7-logs/` (gitignored). Scan JSON written under the
workdir (`endor-local-*.json`) may contain sensitive findings — do not commit them.

See [docs/phase7-validation.md](../../docs/phase7-validation.md) for the full
Buildkite matrix runbook.
