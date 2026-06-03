# Troubleshooting

Onboarding path: [getting-started.md](getting-started.md). Setup details:
[customer-buildkite-setup.md](customer-buildkite-setup.md).

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

## AI-SAST and pull requests

endorctl rejects `--pr` without `--pr-incremental` when `--ai-sast` is enabled. Use
`pr_incremental: true` (with PR id and baseline context), or `pr: false` for
monitoring-style scans on PR builds.

## SCM tokens vs Buildkite OIDC

There is no first-class Buildkite OIDC flow in this plugin for SCM commenting.
Provide a suitable PAT or bot token on the agent (for example via the
Buildkite secrets plugin) and reference it with `scm_token_env`.

## Build tools not visible to `endorctl` (Bazel / Node / …)

- **Log shows `bazel: executable file not found` (or similar) after a successful prebuild**
  — the step `command` often runs `bash ./script.sh` subshells. Exports from those
  scripts do not reach the plugin `post-command` hook unless you append to
  `BUILDKITE_ENV_FILE`, run tools in the step shell without a subshell, or bake them
  into the cluster agent image. See
  [customer-buildkite-setup.md §2](customer-buildkite-setup.md#2-agent-and-cluster-build-tool-prerequisites).
- **This plugin does not install Bazel, Node, Maven, or Docker** — only `endorctl`
  (unless `endorctl_skip_install: true`).

## Buildkite: vendored plugin (recommended)

- **Plugin checkout / `Authentication failed` for `endorlabs-buildkite-plugin.git`**
  — you used a remote `https://github.com/...git#ref` plugin key. The job’s GitHub
  credentials can read your app repo but not the plugin org. **Vendor** the plugin under
  `.buildkite/vendor/endorlabs-buildkite-plugin/` instead (see
  [customer-buildkite-setup.md](customer-buildkite-setup.md)).
- **Build failed but you expected only scan results** — `post-command` runs after your
  `command`. If Bazel/make fails, the step is red even when the plugin runs. Fix the
  build, or split scan into a separate step that depends on a successful build.

## Buildkite annotations (layered / multi-step builds)

- **`annotate: true` has no effect locally** — `buildkite-agent annotate` needs a real
  Buildkite job and agent session token. Local Docker smoke logs a warning and continues.
- **Only the last step’s annotation appears** when several steps use `annotate: true`
  with the default context (`endorlabs-scan`). Set a unique `annotate_context` per step
  (for example `endorlabs-bk-filesystem`, `endorlabs-bk-bazel`).
- **Finding count missing on the annotation** — install `jq` on the agent if you use
  `output_file` / JSON capture; without `jq`, status text still appears but counts may be omitted.
- **Remote plugin uses the wrong ref** — do not use `BUILDKITE_BRANCH` of the
  application repo as the plugin git ref. Prefer vendoring; if you must use a git URL,
  use a single `https://github.com/org/repo.git#ref` string (not `git@github.com:…`
  colon form). Do not write `"${PLUGIN}#${REF}"` in pipeline YAML — Buildkite
  interpolation fails on `}#${`.
- **`pipeline upload` failed: Expected identifier… got #** — combine plugin repo and ref
  into a single variable, use `./` when the plugin is the checked-out repository, or escape
  a literal `#` in pipeline env defaults as `##` ([Buildkite docs](https://buildkite.com/docs/pipelines/configure/definitions#encode-unsafe-characters)).
  Also avoid `${#array[@]}` and `echo "# comment"` in step `command` blocks — use `##` or rewrite without `#`.

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
