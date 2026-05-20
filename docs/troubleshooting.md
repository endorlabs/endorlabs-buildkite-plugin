# Troubleshooting

## Scan outputs and secrets

`output_file`, `sarif_file`, and artifacts uploaded with `upload_artifacts: true`
may contain vulnerability details, file paths, or code snippets. Restrict who can
download Buildkite artifacts and how long they are retained. The plugin does not
log API keys or SCM token values; scan output files are your responsibility to
protect.

## Detached HEAD and branch names

CI agents often check out a commit SHA directly. endorctl still needs a human
branch name for PR and policy behaviour. The plugin passes `BUILDKITE_BRANCH` as
`--detached-ref-name` on every run so scans align with the pipeline branch even
when Git is detached.

## PR baseline and incremental scans

- **`pr_incremental` fails validation** — Ensure `BUILDKITE_PULL_REQUEST` is a
  number, or set `pr_baseline`. You also need baseline context: set
  `pr_baseline`, rely on `BUILDKITE_PULL_REQUEST_BASE_BRANCH`, or use
  `enable_pr_comments: true` so endorctl can infer the merge target.
- **`enable_pr_comments` fails** — Requires a PR build (numeric
  `BUILDKITE_PULL_REQUEST`), `pr: false` must not be set, and `scm_token_env`
  must name a non-empty environment variable on the agent.

## SCM tokens vs Buildkite OIDC

There is no first-class Buildkite OIDC flow in this plugin for SCM commenting.
Provide a suitable PAT or bot token on the agent (for example via the
Buildkite secrets plugin) and reference it with `scm_token_env`.

## Policy exits, soft fail, and fail_on_policy

- **`soft_fail: true`** — the plugin exits 0 even when endorctl returns
  non-zero (useful for informational scans).
- **`fail_on_policy: false`** — policy admission failure (exit `128`) is treated
  as success; other non-zero exits still fail the step unless `soft_fail` is set.
- **`exit_on_policy_warning: true`** — endorctl exit `129` fails the step.

## Artifact sign and verify

`mode: sign` and `mode: verify` call `endorctl artifact sign` / `verify` with
the coordinates you supply. Success depends on your Endor tenant, OIDC issuer
constraints, and artifact registry configuration — not only on plugin YAML.
See the [GitHub Action](https://github.com/endorlabs/github-action) for the same
required inputs.
