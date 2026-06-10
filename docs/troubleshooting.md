# Troubleshooting

Setup: [setup.md](setup.md).

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

## `--pr` vs `--scm-pr-id`

endorctl uses two different PR flags (see [PR scans](https://docs.endorlabs.com/scan/pr-scans)):

- **`--pr`** — PR scan *mode* (point-in-time CI run, not main monitoring).
- **`--scm-pr-id`** — *which* PR/MR id to associate; required for
  `--enable-pr-comments`.

The plugin maps them from Buildkite automatically:

| Plugin input | `--pr` | `--scm-pr-id` |
|--------------|--------|---------------|
| Numeric `BUILDKITE_PULL_REQUEST`, `pr` not `false` | yes | no |
| `enable_pr_comments: true` + numeric `BUILDKITE_PULL_REQUEST` | yes | yes (`BUILDKITE_PULL_REQUEST`) |
| `pr_baseline` set, `pr` not `false` | yes | only with `enable_pr_comments` + numeric PR |
| `pr: false` | no | no |

There is no `scm_pr_id` plugin option — the id comes from
`BUILDKITE_PULL_REQUEST` when `enable_pr_comments` is enabled.

## PR baseline and incremental scans

- **`pr_incremental` fails validation** — Ensure `BUILDKITE_PULL_REQUEST` is a
  number, or set `pr_baseline`. You also need baseline context: set
  `pr_baseline`, rely on `BUILDKITE_PULL_REQUEST_BASE_BRANCH`, or use
  `enable_pr_comments: true` so endorctl can infer the merge target.
- **`enable_pr_comments` fails** — Requires a PR build (numeric
  `BUILDKITE_PULL_REQUEST`), `pr: false` must not be set, and `scm_token_env`
  must name a non-empty environment variable on the agent. PR comments are not
  Buildkite-native: endorctl must call the SCM API using the Endor project's
  registered repo (`git.organization` / `git.path` and `platform_source`) plus
  `--scm-pr-id` and `--scm-token`. For GitHub repos that means a GitHub PAT and
  a PR number that exists on that repo; `BUILDKITE_PULL_REQUEST_BASE_BRANCH` is
  not passed when comments are enabled because endorctl loads the baseline from
  the GitHub/GitLab/Bitbucket PR/MR object instead.

## AI-SAST and pull requests

endorctl rejects `--pr` without `--pr-incremental` when `--ai-sast` is enabled. Use
`pr_incremental: true` (with PR id and baseline context), or `pr: false` for
monitoring-style scans on PR builds.

## Buildkite OIDC vs Endor authentication

Buildkite issues OIDC tokens (`https://agent.buildkite.com`) for federating into
other systems — see [OIDC in Buildkite Pipelines](https://buildkite.com/docs/pipelines/security/oidc).
**endorctl does not accept Buildkite OIDC tokens for Endor API authentication.**
There is no `--enable-buildkite-oidc` flag; do not pass `--enable-github-action-token`
via `additional_args` on Buildkite (GitHub Actions only). Use API credentials
(`api_key_env` / `api_secret_env`) or cloud keyless auth (`aws_role_arn`,
`gcp_service_account`, `enable_azure_managed_identity`) on the agent.

On AWS agents without a static instance profile, you may obtain ambient AWS
credentials first (for example
[aws-assume-role-with-web-identity](https://buildkite.com/docs/pipelines/security/oidc/aws))
and then set `aws_role_arn` for Endor federation — that is still AWS keyless to
Endor, not native Buildkite→Endor OIDC.

`certificate_oidc_issuer` in sign/verify modes is **artifact provenance**, not API
login. Match the issuer to your CI (`https://token.actions.githubusercontent.com`
vs `https://agent.buildkite.com` per tenant policy).

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
  [setup.md §2](setup.md#2-agent-and-cluster-build-tool-prerequisites).
- **This plugin does not install Bazel, Node, Maven, or Docker** — only `endorctl`
  (unless `endorctl_skip_install: true`). The `post-command` hook sources
  `BUILDKITE_ENV_FILE` when present so `PATH` from your step scripts is visible to
  `endorctl`.

## Buildkite: vendored plugin (recommended)

- **Plugin checkout / `Authentication failed` for `endorlabs-buildkite-plugin.git`**
  — you used a remote `https://github.com/...git#ref` plugin key. The job’s GitHub
  credentials can read your app repo but not the plugin org. **Vendor** the plugin under
  `.buildkite/vendor/endorlabs-buildkite-plugin/` instead (see
  [setup.md](setup.md)).
- **`endorlabs#v0.1.0` clones `buildkite-plugins/endorlabs-buildkite-plugin`**
  — Buildkite’s plugin shorthand points at the [plugin directory](https://buildkite.com/docs/pipelines/integrations/plugins/writing#step-2-add-the-plugin-to-your-pipeline)
  mirror until your release is synced. For the **`endorlabs/endorlabs-buildkite-plugin`**
  GitHub repo, use a single full URL:
  `https://github.com/endorlabs/endorlabs-buildkite-plugin.git#v0.1.7`
- **Build failed but you expected only scan results** — `post-command` runs after your
  `command`. If Bazel/make fails, the step is red even when the plugin runs. Fix the
  build, or split scan into a separate step that depends on a successful build.

## Buildkite annotations (layered / multi-step builds)

- **`annotate: true` has no effect locally** — `buildkite-agent annotate` needs a real
  Buildkite job and agent session token. Local Docker smoke logs a warning and continues.
- **Full scan JSON in the step log** — endorctl prints JSON to stdout. With
  `annotate: true` or `output_file` set, the plugin captures that JSON to a temp
  file or your output path instead of echoing it into the log. Set `output_file`
  when you also want a downloadable artifact and an annotation link.
- **“No job annotations” in the job drawer** — the plugin defaults to `annotate_scope: build`
  (build-level Annotations tab). Use `annotate_scope: job` for per-step job annotations
  (requires buildkite-agent v3.112+). With `output_file` set, annotations include a severity
  summary, a top-N findings table (reachability, severity, title, linked location — no code
  snippets), and a link to the JSON artifact. Links use `spec.location_urls` and
  `finding_metadata.custom.location` from scan JSON when present.
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

Endorctl exit **128** is a blocking admission policy failure ([exit codes](https://docs.endorlabs.com/best-practices/troubleshooting/endorctl-exitcodes)).

| `fail_on_policy` | `soft_fail` | Exit 128 | Other non-zero |
|------------------|-------------|----------|----------------|
| `true` (default) | `false` (default) | Step fails | Step fails |
| `false` | `false` | Step passes | Step fails |
| `true` | `true` | Step fails | Step passes |
| `false` | `true` | Step passes | Step passes |

- **`fail_on_policy: false`** — only way to treat exit `128` as success on informational jobs.
- **`soft_fail: true`** — passes the step on other non-zero exits; does **not** bypass exit `128` when `fail_on_policy` is true.
- **`exit_on_policy_warning: true`** — endorctl exit `129` fails the step.

## Artifact sign and verify

`mode: sign` and `mode: verify` call `endorctl artifact sign` / `verify` with
the coordinates you supply. Success depends on your Endor tenant, OIDC issuer
constraints, and artifact registry configuration — not only on plugin YAML.
See the [GitHub Action](https://github.com/endorlabs/github-action) for the same
required inputs.
