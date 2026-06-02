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

## 4. Bazel + Buildkite YAML

Keep `#` and shell `${array[@]}` out of `pipeline.yml` — put Bazel query/build in
a script (see repro-sandbox `scripts/buildkite-bazel-prebuild.sh`).

Ensure Java targets declare strict deps (for example Log4j `log4j-api` alongside
`log4j-core`). A failed `command` can still run the plugin `post-command`, but
`endorctl` Bazel/git scans are more reliable when the prebuild succeeds.

## 5. Troubleshooting

See [troubleshooting.md](troubleshooting.md) for policy exits (`128` / `129`),
plugin checkout, and annotation behaviour.

Maintainers: optional hosted bootstrap notes in
[maintainers/buildkite-hosted-setup.md](maintainers/buildkite-hosted-setup.md).
