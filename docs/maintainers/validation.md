# Maintainer validation

Optional end-to-end checks for plugin maintainers. These exercises use real
`endorctl`, cloned repositories, Docker, and Endor API credentials. They are
**not** run on every pull request to this repository.

**Secrets:** never commit API keys, `paths.env`, resolved pipeline YAML, scan
JSON, or `.validation-logs/`.

## Prerequisites (Buildkite matrix)

- Buildkite organization, pipeline, and Linux agents with Docker (for `image_tar`)
- Plugin checkout on agents at a stable path (see `paths.env.example`)
- Target repositories cloned on agents (django-DefectDojo, Buildkite agent, mongo,
  spring-boot, juice-shop — paths are operator-specific)
- Tenant `namespace` and `ENDOR_API_KEY` / `ENDOR_API_SECRET` via Buildkite secrets

### Example agent paths

| Repository | Example path on agent |
|------------|------------------------|
| django-DefectDojo | `/var/lib/buildkite-agent/git/django-DefectDojo` |
| Buildkite agent | `/var/lib/buildkite-agent/git/agent` |
| mongo | `/var/lib/buildkite-agent/git/mongo` |
| spring-boot | `/var/lib/buildkite-agent/git/spring-boot` |
| juice-shop | `/var/lib/buildkite-agent/git/juice-shop` |

Use forward slashes in `paths.env` on Linux agents.

## Configure paths

1. Copy `scripts/validation/paths.env.example` to `scripts/validation/paths.env`
   (gitignored).
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

`--upload` writes `.buildkite/validation/matrix.resolved.yml` (gitignored) and
runs `buildkite-agent pipeline upload`.

Matrix definition: [.buildkite/validation/matrix.yml](../../.buildkite/validation/matrix.yml)
(scan toggles, PR/baseline, container, sign/verify smoke, artifacts, policy exits,
annotations).

## Local Docker smoke

For development without a Buildkite server, see
[contrib/local-smoke/README.md](../../contrib/local-smoke/README.md).

Set `VALIDATION_WORK_DIR` to an absolute path of a git checkout. Credentials come
from a gitignored `.env` at the repository root (API key vars only; do not mix
`ENDOR_TOKEN` with API credentials).

Logs: `.validation-logs/` (gitignored). Scan JSON under the workdir
(`endor-local-*.json`) may contain sensitive findings — do not commit.

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
