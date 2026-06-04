# Buildkite setup

Configure [endorctl](https://docs.endorlabs.com/developers-api/cli/commands/scan) on Buildkite with API keys (same model as the [GitHub Action](https://github.com/endorlabs/github-action)). Do not mix `ENDOR_TOKEN` bearer auth with API keys on the same job.

**Official docs:** [Endor scan](https://docs.endorlabs.com/scan) · [Buildkite cluster secrets](https://buildkite.com/docs/agent/v3/clusters/secrets) · [Writing plugins](https://buildkite.com/docs/pipelines/integrations/plugins/writing)

**Plugin docs:** [index](README.md) · [examples](examples.md) · [troubleshooting](troubleshooting.md)

## Quick start

1. Create cluster secrets: `ENDOR_NAMESPACE`, `ENDOR_API_CREDENTIALS_KEY`, `ENDOR_API_CREDENTIALS_SECRET`.
2. Vendor the plugin (recommended when the plugin repo is in another GitHub org):

```bash
ENDORLABS_PLUGIN_SRC=/path/to/endorlabs-buildkite-plugin \
  ./scripts/sync-vendor-endorlabs-plugin.sh
git add .buildkite/vendor/endorlabs-buildkite-plugin
```

3. Add a step — **`command` runs first**, then the plugin **`post-command`** hook. Install build tools in `command` or on the agent image (§2).

```yaml
secrets:
  - ENDOR_NAMESPACE
  - ENDOR_API_CREDENTIALS_KEY
  - ENDOR_API_CREDENTIALS_SECRET

steps:
  - label: ":hammer: Build and scan"
    command: "make build"
    plugins:
      - ./.buildkite/vendor/endorlabs-buildkite-plugin:
          namespace: "${ENDOR_NAMESPACE}"
          api_key_env: ENDOR_API_CREDENTIALS_KEY
          api_secret_env: ENDOR_API_CREDENTIALS_SECRET
          scan_dependencies: true
          annotate: true
```

Do not duplicate `ENDOR_NAMESPACE` under top-level `env:` when it is already under `secrets:`.

4. Confirm the build log shows `:endorlabs: Running endorctl scan`. Policy blocking uses exit `128` by default (`fail_on_policy: true`). See [troubleshooting.md](troubleshooting.md) for exits and clone issues.

**Public plugin ref:** use `https://github.com/endorlabs/endorlabs-buildkite-plugin.git#v0.1.4` until `endorlabs#v0.1.4` appears in the [plugins directory](https://buildkite.com/docs/integrations/buildkite-plugins). Vendoring still works for air-gapped or cross-org constraints.

More YAML: [examples.md](examples.md). Demo: [repro-sandbox](https://github.com/endorlabs/repro-sandbox).

## 1. Credentials on the agent

| Variable | How to set it |
|----------|----------------|
| `ENDOR_NAMESPACE` | **Cluster secret** or pipeline environment variable (tenant id; not committed to git) |
| `ENDOR_API_CREDENTIALS_KEY` | **Buildkite cluster secret** → exposed to jobs with that name |
| `ENDOR_API_CREDENTIALS_SECRET` | **Buildkite cluster secret** → exposed to jobs with that name |

Create secrets under **Agents → your cluster → Secrets** in Buildkite. Scope to your pipeline (for example `pipeline_slug: my-app`).

The plugin reads the **names** in `api_key_env` / `api_secret_env`; it never prints secret values.

## 2. Agent and cluster build-tool prerequisites

This plugin installs **endorctl** only (`bash` + `curl` in [`plugin.yml`](../plugin.yml)). Bazel, Node, Docker, `jq`, and other toolchains belong on the agent image or in step **`command`** before the hook.

| Responsibility | Examples |
|----------------|----------|
| **Cluster / agent image** | Bazelisk, JDK, Node/npm, Docker, `jq` |
| **Pipeline `command`** | `make build`, `bazel build` — before `post-command` |
| **Cluster secrets** | Endor credentials only |

Exports from subshell scripts are not visible to the hook unless persisted to [`BUILDKITE_ENV_FILE`](https://buildkite.com/docs/pipelines/environment-variables#BUILDKITE_ENV_FILE) or baked into the image.

```yaml
steps:
  - label: ":bazel: Build and scan"
    command: |
      export PATH="${HOME}/.local/bin:${PATH}"
      echo "PATH=${PATH}" >> "${BUILDKITE_ENV_FILE}"
      bazel build //app/...
    plugins:
      - ./.buildkite/vendor/endorlabs-buildkite-plugin:
          use_bazel: true
          bazel_include_targets: "//app/..."
```

Example helper: [repro-sandbox `buildkite-ensure-build-tools.sh`](https://github.com/endorlabs/repro-sandbox/blob/main/scripts/buildkite-ensure-build-tools.sh).

## 3. Plugin source — vendored (recommended)

```yaml
plugins:
  - ./.buildkite/vendor/endorlabs-buildkite-plugin:
      namespace: "${ENDOR_NAMESPACE}"
      api_key_env: ENDOR_API_CREDENTIALS_KEY
      api_secret_env: ENDOR_API_CREDENTIALS_SECRET
```

Refresh with [`scripts/sync-vendor-endorlabs-plugin.sh`](../scripts/sync-vendor-endorlabs-plugin.sh) and commit `VENDOR_SOURCE.json`.

## 4. Layered scans

Use a distinct `annotate_context` per step. Keep `fail_on_policy: true` on merge gates; use `fail_on_policy: false` only on informational jobs.

## 5. Annotations and job artifacts

| Location | Purpose |
|----------|---------|
| Agent checkout | `output_file` / `sarif_file` on disk during the job |
| Buildkite artifacts | Uploaded when `upload_artifacts: true` (defaults on if paths are set) |

```yaml
output_file: ".local/scans/endor-scan.json"
sarif_file: ".local/scans/endor-scan.sarif"
upload_artifacts: true
```

Create directories in `command` if needed (`mkdir -p .local/scans`). Treat artifacts as sensitive. Annotations (`annotate: true`) are HTML summaries in the UI, not downloadable scan files.

## 6. Bazel + pipeline YAML

Keep `#` and `${array[@]}` out of `pipeline.yml` when possible — use scripts. With `use_bazel: true`, prebuild targets in `command` before the hook.

## 7. AI-SAST and pull requests

`--ai-sast` on PR builds may require `pr_incremental: true` or `pr: false` — see [troubleshooting.md](troubleshooting.md).

## 8. Troubleshooting

Policy exits, plugin clone, PR flags: [troubleshooting.md](troubleshooting.md). Full options: [`plugin.yml`](../plugin.yml).
