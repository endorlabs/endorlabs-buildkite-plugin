# Buildkite hosted setup (maintainers)

One-time configuration so hosted Elastic agents can run real `endorctl` scans. Values come from your local `.env`; **never commit** `.env` or secret values.

## Map `.env` to Buildkite

| Local `.env` | Buildkite |
|--------------|-----------|
| `ENDOR_NAMESPACE` | Pipeline or team **environment variable** `ENDOR_NAMESPACE` |
| `ENDOR_API_CREDENTIALS_KEY` | **Secret** → exposed to jobs as env `ENDOR_API_CREDENTIALS_KEY` |
| `ENDOR_API_CREDENTIALS_SECRET` | **Secret** → exposed to jobs as env `ENDOR_API_CREDENTIALS_SECRET` |
| `BUILDKITE_API_TOKEN` | Local CLI / API only (not injected into scan jobs) |

Do **not** set `ENDOR_TOKEN` on agents when using API keys (endorctl exit `4`).

## Pipelines

| Pipeline | Repository | Config file | Default branch |
|----------|------------|-------------|----------------|
| `repro-sandbox` | repro-sandbox | `.buildkite/pipeline.yml` | `dev` |
| `endorlabs-buildkite-plugin-validation` | endorlabs-buildkite-plugin | `.buildkite/pipeline.validation-smoke.yml` | `main` |

## Private plugin clone (repro-sandbox)

Hosted agents clone the plugin by git ref (`ENDORLABS_BUILDKITE_PLUGIN`). If `endorlabs/endorlabs-buildkite-plugin` is private:

1. Add a **pipeline SSH key** or org **GitHub connection** so agents can `git clone git@github.com:endorlabs/endorlabs-buildkite-plugin.git`.
2. Or set pipeline env `ENDORLABS_BUILDKITE_PLUGIN` to a fork URL you control.
3. De-risk first: run the plugin repo’s **validation-smoke** pipeline (uses `$BUILDKITE_REPO#$BUILDKITE_COMMIT` — no separate plugin clone).

## Helper script

From the plugin repo root (Git Bash / WSL / Linux):

```bash
# Dry-run: print what would be configured
./scripts/setup-buildkite-secrets.sh --dry-run

# Apply org env + pipeline secrets (requires BUILDKITE_API_TOKEN in .env)
./scripts/setup-buildkite-secrets.sh --org tim-gowan --pipeline repro-sandbox
./scripts/setup-buildkite-secrets.sh --org tim-gowan --pipeline endorlabs-buildkite-plugin-validation
```

## Trigger builds

```bash
export BUILDKITE_API_TOKEN=...   # from .env, local only
bk build create --org tim-gowan --pipeline repro-sandbox --branch dev
bk build create --org tim-gowan --pipeline endorlabs-buildkite-plugin-validation --branch main
```
