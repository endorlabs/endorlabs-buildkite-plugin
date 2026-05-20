# Phase 7 — real-repo validation runbook

Optional end-to-end validation of the Endor Labs Buildkite plugin against diverse
repositories on Buildkite agents with API-key authentication (`api_key_env` /
`api_secret_env`).

## Local Docker smoke tests (maintainers)

For development without a Buildkite server, see
[contrib/phase7-local/README.md](../contrib/phase7-local/README.md).

| File | Purpose |
|------|---------|
| `contrib/phase7-local/docker-compose.phase7-local.yml` | Linux agent image, mounts plugin + workdir |
| `contrib/phase7-local/local-juice-shop.sh` | Bash driver |
| `contrib/phase7-local/run-phase7-docker.ps1` | PowerShell driver |

Set `PHASE7_WORK_DIR` to an absolute path of a git checkout. Credentials come from
a gitignored `.env` at the repository root (API key vars only; do not mix
`ENDOR_TOKEN` with API credentials).

Logs: `.phase7-logs/` (gitignored). Scan JSON under the workdir (`endor-local-*.json`)
may contain sensitive findings — do not commit.

## Prerequisites (Buildkite matrix)

- **Buildkite**: Organization, pipeline, and Linux agents with Docker (for `image_tar`).
- **Plugin checkout** on agents at a stable path referenced by the matrix pipeline.
- **Target repositories** cloned on agents; paths in `scripts/phase7/phase7.paths.env`
  (copy from `phase7.paths.env.example`).
- **Endor Labs**: Tenant `namespace` and API credentials as `ENDOR_API_KEY` /
  `ENDOR_API_SECRET` (or equivalent) via Buildkite secrets — never commit secrets.

### Example agent paths

| Repository | Example path on agent |
|------------|------------------------|
| django-DefectDojo | `/var/lib/buildkite-agent/git/django-DefectDojo` |
| Buildkite agent | `/var/lib/buildkite-agent/git/agent` |
| mongo | `/var/lib/buildkite-agent/git/mongo` |
| spring-boot | `/var/lib/buildkite-agent/git/spring-boot` |
| juice-shop | `/var/lib/buildkite-agent/git/juice-shop` |

Use forward slashes in `phase7.paths.env` on Linux agents.

## Configure paths

1. Copy `scripts/phase7/phase7.paths.env.example` to `scripts/phase7/phase7.paths.env`.
2. Set `ENDORLABS_BUILDKITE_PLUGIN_REF`, for example:
   - `file:///var/lib/buildkite-agent/plugins/endorlabs-buildkite-plugin`
   - `ssh://git@github.com/endorlabs/endorlabs-buildkite-plugin#main`
3. Set each `PHASE7_REPO_*` to the checkout root on the agent.
4. Set `ENDOR_NAMESPACE` (tenant identifier, not a secret).

## Render and upload the pipeline

From the plugin repository root:

```bash
scripts/phase7/run-repo-matrix.sh --check-only
scripts/phase7/run-repo-matrix.sh --render /tmp/phase7-rendered.yml
scripts/phase7/run-repo-matrix.sh --upload
```

`--upload` writes `.buildkite/pipeline.phase7.resolved.yml` (gitignored) and runs
`buildkite-agent pipeline upload`.

## Matrix coverage

See `.buildkite/pipeline.phase7.yml` for scan toggles, PR/baseline, container,
sign/verify smoke steps, artifacts, policy exits, and annotations.

## Annotation acceptance (Buildkite UI)

For steps with `annotate: true`, confirm context keys: `endorlabs-scan`,
`endorlabs-container`, `endorlabs-sign`, `endorlabs-verify`. Body must not
contain secrets (BATS cover wiring with stubbed `buildkite-agent`).

## Evidence and gaps

- Evidence template: [docs/phase7/evidence/README.md](phase7/evidence/README.md)
- Gap report: [docs/phase7/gap-report.md](phase7/gap-report.md)
