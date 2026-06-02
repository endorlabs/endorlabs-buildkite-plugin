# Buildkite customer setup

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

## 2. Plugin source (choose one)

### Recommended: vendored plugin (cross-org, air-gapped friendly)

Copy the plugin into your repo (for example
`.buildkite/vendor/endorlabs-buildkite-plugin/`) and pin provenance in
`VENDOR_SOURCE.json`. No second git clone during the job.

```yaml
plugins:
  - ./.buildkite/vendor/endorlabs-buildkite-plugin:
      namespace: "${ENDOR_NAMESPACE}"
      api_key_env: ENDOR_API_CREDENTIALS_KEY
      api_secret_env: ENDOR_API_CREDENTIALS_SECRET
```

See [repro-sandbox](https://github.com/endorlabs/repro-sandbox) for a full
layered-scan example (filesystem + Bazel).

### Alternative: git URL plugin

```yaml
plugins:
  - https://github.com/endorlabs/endorlabs-buildkite-plugin.git#v0.1.0:
      namespace: "${ENDOR_NAMESPACE}"
      api_key_env: ENDOR_API_CREDENTIALS_KEY
      api_secret_env: ENDOR_API_CREDENTIALS_SECRET
```

Requirements:

- Use `https://github.com/org/repo.git#ref` (not `git@github.com:org/repo.git`).
- Do not split repo and ref in YAML as `"${REPO}#${REF}"` — Buildkite
  interpolation breaks on `}#${`.
- The Buildkite GitHub App (or SSH key) for the **agent** must be able to
  **read the plugin repository**. An app on your app repo alone does not grant
  access to a plugin in another org.

## 3. Layered scans (multiple steps)

Use a distinct `annotate_context` per step so annotations are not overwritten:

```yaml
annotate_context: endorlabs-filesystem
```

Use `fail_on_policy: false` only on informational or comparison jobs; keep
`fail_on_policy: true` (default) on merge gates.

## 4. Annotations and job artifacts

### Annotations (`annotate: true`)

After the scan, the plugin runs `buildkite-agent annotate` with `annotate_context`
(unique per step). In the Buildkite UI, open the **scan step** → **Annotations**
(context matches your `annotate_context`, e.g. `endorlabs-bk-filesystem`).

Vendored plugin paths (`./.buildkite/vendor/endorlabs-buildkite-plugin`) use a
longer Buildkite env prefix (`BUILDKITE_PLUGIN_ENDORLABS_BUILDKITE_PLUGIN_*`);
the plugin resolves that automatically.

### JSON / SARIF files and artifacts

| Option | Purpose |
|--------|---------|
| `output_file` | Tee endorctl JSON summary to this path |
| `sarif_file` | Pass `--sarif-file=` to endorctl |
| `upload_artifacts` | `buildkite-agent artifact upload` for those paths |

**Recommended path** (gitignored, one directory per repo):

```yaml
output_file: ".local/scans/endor-scan.json"
sarif_file: ".local/scans/endor-scan.sarif"
upload_artifacts: true
```

If `output_file` or `sarif_file` is set and `upload_artifacts` is omitted, the
plugin defaults `upload_artifacts` to **true** so files appear under the job
**Artifacts** tab in Buildkite. Set `upload_artifacts: false` to keep outputs
on the agent only.

Create the directory in your step command if needed: `mkdir -p .local/scans`.

Treat artifacts as sensitive (findings, paths); restrict retention and download
access in Buildkite.

## 5. Bazel + Buildkite YAML

Keep `#` and shell `${array[@]}` out of `pipeline.yml` — put Bazel query/build in
a script (see repro-sandbox `scripts/buildkite-bazel-prebuild.sh`).

Ensure Java targets declare strict deps (for example Log4j `log4j-api` alongside
`log4j-core`). A failed `command` can still run the plugin `post-command`, but
`endorctl` Bazel/git scans are more reliable when the prebuild succeeds.

## 6. Troubleshooting

See [troubleshooting.md](troubleshooting.md) for policy exits (`128` / `129`),
plugin checkout, and annotation behaviour.

Maintainers: optional hosted bootstrap notes in
[maintainers/buildkite-hosted-setup.md](maintainers/buildkite-hosted-setup.md).
