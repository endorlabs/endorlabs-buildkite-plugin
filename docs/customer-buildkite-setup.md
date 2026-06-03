# Buildkite customer setup

Step-by-step onboarding: [getting-started.md](getting-started.md). This page covers
secrets, vendoring, outputs, and Bazel notes in more detail.

Configure Endor Labs scans on [Buildkite](https://buildkite.com) with API keys
(the same credential model as the
[GitHub Action](https://github.com/endorlabs/github-action)). Do not mix
`ENDOR_TOKEN` bearer auth with API keys on the same job.

## 1. Credentials on the agent

| Variable | How to set it |
|----------|----------------|
| `ENDOR_NAMESPACE` | **Cluster secret** or pipeline environment variable (tenant id; not committed to git) |
| `ENDOR_API_CREDENTIALS_KEY` | **Buildkite cluster secret** → exposed to jobs with that name |
| `ENDOR_API_CREDENTIALS_SECRET` | **Buildkite cluster secret** → exposed to jobs with that name |

Create secrets under **Agents → your cluster → Secrets** in Buildkite. Use a
policy that limits access to your pipeline (for example `pipeline_slug: my-app`).

Reference them in pipeline YAML (Buildkite agent **3.106.0+**):

```yaml
# Do not list ENDOR_NAMESPACE under env: if it is a cluster secret — Buildkite rejects duplicates.
secrets:
  - ENDOR_NAMESPACE
  - ENDOR_API_CREDENTIALS_KEY
  - ENDOR_API_CREDENTIALS_SECRET

steps:
  - label: ":endorlabs: Require Endor API credentials"
    command: |
      test -n "${ENDOR_API_CREDENTIALS_KEY}" \
        && test -n "${ENDOR_API_CREDENTIALS_SECRET}"
  - label: ":endorlabs: Require Endor namespace"
    command: test -n "${ENDOR_NAMESPACE}"
  - label: ":hammer: Build and scan"
    command: "make build"
    plugins:
      - endorlabs#v0.1.0:
          namespace: "${ENDOR_NAMESPACE}"
          api_key_env: ENDOR_API_CREDENTIALS_KEY
          api_secret_env: ENDOR_API_CREDENTIALS_SECRET
          scan_dependencies: true
          annotate: true
```

The plugin reads the **names** you pass in `api_key_env` / `api_secret_env`; it
never prints secret values.

## 2. Plugin source — vendored (recommended)

Copy the plugin into your repo (for example
`.buildkite/vendor/endorlabs-buildkite-plugin/`) and pin provenance in
`VENDOR_SOURCE.json`. No second git clone during the job; works when the
Buildkite GitHub App is installed only on your application repository.

```yaml
plugins:
  - ./.buildkite/vendor/endorlabs-buildkite-plugin:
      namespace: "${ENDOR_NAMESPACE}"
      api_key_env: ENDOR_API_CREDENTIALS_KEY
      api_secret_env: ENDOR_API_CREDENTIALS_SECRET
```

Refresh from upstream with
[`scripts/sync-vendor-endorlabs-plugin.sh`](../scripts/sync-vendor-endorlabs-plugin.sh)
(record provenance in `VENDOR_SOURCE.json`). Working example:
[repro-sandbox](https://github.com/endorlabs/repro-sandbox) on Buildkite.

Do **not** point the plugin key at a remote `https://github.com/...git#ref` unless
agents can clone that repo and you accept a second checkout per job — vendoring
avoids cross-org clone failures. See [troubleshooting.md](troubleshooting.md) if
you hit plugin checkout auth errors.

## 3. Layered scans (multiple steps)

Use a distinct `annotate_context` per step so annotations are not overwritten:

```yaml
annotate_context: endorlabs-filesystem
```

Use `fail_on_policy: false` only on informational or comparison jobs; keep
`fail_on_policy: true` (default) on merge gates.

## 4. Annotations and job artifacts

### Where outputs live (two places)

| Location | What it is | Lifetime |
|----------|------------|----------|
| **Agent checkout** (during the job) | Files on disk at the paths you set in `output_file` / `sarif_file` (relative to the repo root on the agent, usually `$BUILDKITE_BUILD_CHECKOUT_PATH`) | Deleted when the agent tears down the job workspace |
| **Buildkite artifact storage** (after upload) | Copies uploaded with `buildkite-agent artifact upload` when `upload_artifacts: true` | Kept per your org/pipeline **artifact retention** settings; downloadable from the UI |

The plugin does **not** send files to Endor Labs as Buildkite artifacts — scan results still go to the Endor API via `endorctl`. Buildkite artifacts are for **your** CI download, SARIF import elsewhere, or debugging.

**repro-sandbox example paths** (default demo pipeline):

- `.local/scans/endor-demo.json`
- `.local/scans/endor-demo.sarif`

### Finding artifacts in the Buildkite UI

Navigation (wording can vary slightly by Buildkite version):

1. Open your **organization** (for example `your-org`).
2. **Pipelines** → your pipeline (for example `repro-sandbox`).
3. Click a **build number** (for example build `#35`).
4. In the pipeline graph, click the **scan step** (for example `:endorlabs: Bazel security scan`).
5. Open the step’s **Artifacts** tab (sometimes labeled **Job artifacts**).

You should see one row per uploaded file (for example `endor-demo.json`). Use **Download** to pull a copy. Paths in the list are the same as in your YAML (`output_file` / `sarif_file`), not a separate “folder” in the UI.

**Build-level view:** Some builds also show an **Artifacts** section on the main build page that aggregates files from all steps — useful when you have layered scans with different `output_file` names per step.

**If the Artifacts tab is empty:**

- `upload_artifacts` is `false` and you did not rely on the auto-default (see below).
- The file was never created (scan failed before write, or wrong path).
- The step `command` did not create the parent directory — use `mkdir -p .local/scans` in `command` (repro does this).
- Check the step **Log** for `Uploading artifact` or `artifact path not found, skipping upload`.

### Annotations (`annotate: true`) — not the same as artifacts

Annotations are **HTML summaries** attached to the build/step in the UI, not downloadable scan files.

1. Same build → click the scan step.
2. Open **Annotations** (not Artifacts).
3. Look for the **context** you set in `annotate_context` (for example `endorlabs-demo`).

Vendored plugin paths (`./.buildkite/vendor/endorlabs-buildkite-plugin`) use a
longer Buildkite env prefix (`BUILDKITE_PLUGIN_ENDORLABS_BUILDKITE_PLUGIN_*`);
the plugin resolves that automatically.

### JSON / SARIF plugin options

| Option | Purpose |
|--------|---------|
| `output_file` | Tee endorctl JSON summary to this path on the agent |
| `sarif_file` | Pass `--sarif-file=` to endorctl |
| `upload_artifacts` | Run `buildkite-agent artifact upload` for those paths after the scan |
| `artifact_paths` | Optional extra paths (whitespace-separated); overrides the default list built from `output_file` / `sarif_file` |

**Recommended path** (gitignored, one directory per repo):

```yaml
output_file: ".local/scans/endor-scan.json"
sarif_file: ".local/scans/endor-scan.sarif"
upload_artifacts: true
```

If `output_file` or `sarif_file` is set and `upload_artifacts` is omitted, the
plugin defaults `upload_artifacts` to **true**. Set `upload_artifacts: false` to
keep outputs on the agent only (no Buildkite Artifacts tab).

Create the directory in your step command if needed: `mkdir -p .local/scans`.

Treat artifacts as sensitive (findings, paths); restrict retention and download
access in Buildkite.

## 5. Bazel + Buildkite YAML

Keep `#` and shell `${array[@]}` out of `pipeline.yml` — put Bazel query/build in
a script (see repro-sandbox `scripts/buildkite-bazel-prebuild.sh`).

Ensure Java targets declare strict deps (for example Log4j `log4j-api` alongside
`log4j-core`). A failed `command` can still run the plugin `post-command`, but
`endorctl` Bazel/git scans are more reliable when the prebuild succeeds.

## 6. AI-SAST and pull requests

If you pass `--ai-sast` (via `additional_args`) on a **PR build**, endorctl requires
`--pr-incremental` when `--pr` is set. For a simple monitoring scan on every branch,
set `pr: false` on the plugin step, or enable `pr_incremental: true` with baseline
context — see [troubleshooting.md](troubleshooting.md).

## 7. Working example

See [repro-sandbox](https://github.com/endorlabs/repro-sandbox) for a vendored
plugin pipeline on Buildkite (default demo: Bazel-targeted scan).

## 8. Troubleshooting

See [troubleshooting.md](troubleshooting.md) for policy exits (`128` / `129`),
plugin checkout, and annotation behaviour.
