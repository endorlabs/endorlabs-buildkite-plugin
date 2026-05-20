# Maintainer validation

Optional end-to-end checks for plugin maintainers. These exercises use real
`endorctl`, cloned repositories, Docker, and Endor API credentials. They are
**not** run on every pull request to this repository.

## What ships in git vs what stays local

| In the repository (PR CI) | On your machine only (`.local/`, gitignored) |
|-------------------------|-----------------------------------------------|
| `hooks/`, `lib/`, `plugin.yml` | `.env` (API credentials) |
| `tests/*.bats` (stubbed `endorctl`) | `.local/paths.env` (agent paths for matrix render) |
| shellcheck, plugin-linter, BATS in GHA / `.buildkite/pipeline.yml` | `.local/logs/` (local-smoke transcripts) |
| `scripts/validation/paths.env.example` (template) | `.local/scans/` (`endor-local-*.json`, SARIF, etc.) |
| `.buildkite/validation/matrix.yml` (parametrized template) | `.local/matrix.resolved.yml` (rendered upload YAML) |

PRs validate the **plugin contract** with stubs. Real scans write artifacts only under
**`.local/`** or on external checkouts you scan (Juice Shop stays clean — scan outputs
go to `.local/scans/`, not into the target repo).

**Secrets:** never commit API keys, `.env`, or anything under `.local/`.

## Prerequisites (Buildkite matrix)

- Buildkite organization, pipeline, and Linux agents with Docker (for `image_tar`)
- Plugin checkout on agents at a stable path (see `paths.env.example`)
- **Canonical target:** [juice-shop v20.0.0](https://github.com/juice-shop/juice-shop/releases/tag/v20.0.0)
  at commit `f356a09207c7a9550eb6fc4c3945e081922cf998` (pin; do not scan floating `main`)
- Optional extended matrix repos (DefectDojo, agent, mongo, spring-boot) — paths are
  operator-specific; not required for basic smoke
- Tenant `namespace` and `ENDOR_API_KEY` / `ENDOR_API_SECRET` via Buildkite secrets

### Example agent paths

| Repository | Example path on agent |
|------------|------------------------|
| django-DefectDojo | `/var/lib/buildkite-agent/git/django-DefectDojo` |
| Buildkite agent | `/var/lib/buildkite-agent/git/agent` |
| mongo | `/var/lib/buildkite-agent/git/mongo` |
| spring-boot | `/var/lib/buildkite-agent/git/spring-boot` |
| juice-shop (canonical) | `/var/lib/buildkite-agent/git/juice-shop` @ `f356a092…` (v20.0.0) |

Clone the canonical target:

```bash
git clone https://github.com/juice-shop/juice-shop.git /var/lib/buildkite-agent/git/juice-shop
cd /var/lib/buildkite-agent/git/juice-shop
git checkout f356a09207c7a9550eb6fc4c3945e081922cf998
```

Use forward slashes in `.local/paths.env` on Linux agents.

## Configure paths

1. Copy `scripts/validation/paths.env.example` to `.local/paths.env` (gitignored).
2. Set `ENDORLABS_BUILDKITE_PLUGIN_REF`, for example:
   - `file:///var/lib/buildkite-agent/plugins/endorlabs-buildkite-plugin`
   - `ssh://git@github.com/endorlabs/endorlabs-buildkite-plugin#main`
3. Set each `VALIDATION_REPO_*` to the checkout root on the agent.
4. Set `ENDOR_NAMESPACE` (tenant identifier, not a secret).

## Render and upload the matrix

From the plugin repository root:

```bash
scripts/validation/render-matrix.sh --check-only
scripts/validation/render-matrix.sh --render /tmp/validation-rendered.yml
scripts/validation/render-matrix.sh --upload
```

`--upload` writes `.local/matrix.resolved.yml` (gitignored) and runs
`buildkite-agent pipeline upload`.

Matrix definition: [.buildkite/validation/matrix.yml](../../.buildkite/validation/matrix.yml)
(scan toggles, PR/baseline, container, sign/verify smoke, artifacts, policy exits,
annotations).

## Local Docker smoke

For development without a Buildkite server, see
[contrib/local-smoke/README.md](../../contrib/local-smoke/README.md).

Set `VALIDATION_WORK_DIR` to an absolute path of a git checkout (for example
`G:\GitHub\juice-shop` or `/var/lib/buildkite-agent/git/juice-shop` at the pinned
commit). Credentials come from a gitignored `.env` at the repository root (API key
vars only; do not mix `ENDOR_TOKEN` with API credentials).

Artifacts from local-smoke:

- Logs: `.local/logs/`
- Scan JSON: `.local/scans/endor-local-*.json`

The target checkout is read-only for scanning; outputs do not land in Juice Shop.

## Annotation checklist (Buildkite UI)

For steps with `annotate: true`, confirm context keys: `endorlabs-scan`,
`endorlabs-container`, `endorlabs-sign`, `endorlabs-verify`. The annotation body
must not contain secrets (BATS cover wiring with stubbed `buildkite-agent`).

## Recording results

After a validation wave, note pass/fail per matrix step key, endorctl exit code,
and annotation context in your team's issue tracker or internal runbook. No
committed evidence bundle is required in this repository.

## Known limitations

- **Sign / verify:** matrix smoke steps use placeholder artifact coordinates and
  `soft_fail: true`. Real signing needs tenant and artifact configuration per the
  [GitHub Action](https://github.com/endorlabs/github-action).
- **Windows agents:** hooks and the validation matrix target bash/Linux.
- **Versioned plugin ref:** prefer `endorlabs/endorlabs-buildkite-plugin#v…` in
  customer pipelines instead of agent-local `file://` paths.
