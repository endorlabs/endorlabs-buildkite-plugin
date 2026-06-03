# Examples

Plugin keys mirror the official
[Endor Labs GitHub Action](https://github.com/endorlabs/github-action) where
applicable (`namespace`, scan toggles, PR options, container, sign/verify).
See [`plugin.yml`](../plugin.yml) for the full schema.

**Recommended:** vendored plugin path + Buildkite cluster secrets (see
[setup.md](setup.md)). For the public git plugin,
use the full GitHub URL with release tag v0.1.2 (see [troubleshooting.md](troubleshooting.md)
for shorthand vs directory mirror).

## Buildkite: cluster secrets + vendored plugin

See [setup.md](setup.md). Minimal YAML:

```yaml
secrets:
  - ENDOR_NAMESPACE
  - ENDOR_API_CREDENTIALS_KEY
  - ENDOR_API_CREDENTIALS_SECRET

steps:
  - command: "make build"
    plugins:
      - ./.buildkite/vendor/endorlabs-buildkite-plugin:
          namespace: "${ENDOR_NAMESPACE}"
          api_key_env: ENDOR_API_CREDENTIALS_KEY
          api_secret_env: ENDOR_API_CREDENTIALS_SECRET
          scan_dependencies: true
          annotate: true
```

## Minimal: SCA scan after build (git plugin reference)

Run the user step's `command`, then scan dependencies as a `post-command`.
Use when agents can clone `github.com/endorlabs/endorlabs-buildkite-plugin`.

```yaml
steps:
  - label: ":hammer: Build and scan"
    command: "make build"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
```

The plugin requires API credentials to be present on the agent under
the env-var names you pass in `api_key_env` / `api_secret_env`. On
Buildkite, use cluster secrets and a pipeline `secrets:` block — see
[setup.md](setup.md). Never commit
credential values to your pipeline file.

## Pin endorctl version

Pin a specific endorctl release and verify its SHA-256 checksum at install
time. Pinning is recommended for reproducible builds.

```yaml
steps:
  - command: "make build"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          endorctl_version: "1.2.3"
          endorctl_checksum: "<sha256-of-the-binary-for-your-platform>"
```

## Skip install (agent has endorctl baked in)

If your Buildkite agent image already includes `endorctl` on `PATH`, you
can skip the download.

```yaml
steps:
  - command: "make build"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          endorctl_skip_install: true
```

## Keyless auth: AWS role ARN

```yaml
steps:
  - command: "make test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          aws_role_arn: "arn:aws:iam::123456789012:role/endorlabs-federation-role"
```

## Keyless auth: Azure managed identity

```yaml
steps:
  - command: "make test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          enable_azure_managed_identity: true
```

## Keyless auth: GCP service account

```yaml
steps:
  - command: "make test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          gcp_service_account: "endorlabs-federation@my-project.iam.gserviceaccount.com"
```

## SARIF output + scan path

Emit SARIF for upload to GitHub Code Scanning or other tools, and limit
the scan to a sub-directory of the checkout.

```yaml
steps:
  - command: "./gradlew assemble"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          scan_path: "services/api"
          sarif_file: "endor.sarif"
          output_type: "json"
```

## Multi-signal repo scan

Enable additional scan kinds beyond dependencies.

```yaml
steps:
  - command: "./gradlew test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          scan_dependencies: true
          scan_secrets: true
          scan_sast: true
          scan_tools: true
          scan_github_actions: true
          phantom_dependencies: true
```

## Bazel monorepos

Install **Bazelisk + JDK** on the Buildkite cluster agent (or bootstrap in `command`);
run `bazel build` for your targets before the plugin hook. The plugin passes
`--use-bazel` and target flags to `endorctl` but does not install Bazel — see
[setup.md §2–§6](setup.md#2-agent-and-cluster-build-tool-prerequisites).

For Bazel target selection, aspects, and layered scan examples, see
[repro-sandbox](https://github.com/endorlabs/repro-sandbox) (`buildkite-ensure-build-tools.sh`,
optional `pipeline.layered-scans.yml`). Core plugin options: `use_bazel`,
`bazel_include_targets`, `bazel_exclude_targets`, and `bazel_targets_query`
(omit `bazel_targets_query` when `--bazel-include-targets` is set in
`additional_args`).

## Pull-request scans (auto-detect)

On PR-triggered pipelines, Buildkite sets `BUILDKITE_PULL_REQUEST` to the pull
request number (digits only), and usually sets `BUILDKITE_BRANCH` and
`BUILDKITE_PULL_REQUEST_BASE_BRANCH`. With `pr` omitted or `true`, the plugin
maps these to `--detached-ref-name`, `--pr=true`, `--scm-pr-id`, and
`--pr-baseline` (from the base branch when you do not override `pr_baseline`).

```yaml
steps:
  - command: "make test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
```

## Explicit PR baseline

When Buildkite does not populate the base branch (or you need a non-default
target), set `pr_baseline` explicitly. It overrides `BUILDKITE_PULL_REQUEST_BASE_BRANCH`.

```yaml
steps:
  - command: "make test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          pr_baseline: "release/2.x"
```

## Incremental PR scan

Enable `pr_incremental` for dependency scans that only consider changes relative
to the baseline. You need a numeric `BUILDKITE_PULL_REQUEST` or `pr_baseline`,
and either `BUILDKITE_PULL_REQUEST_BASE_BRANCH`, `pr_baseline`, or
`enable_pr_comments` so a baseline exists (comments mode lets endorctl infer the
merge target).

```yaml
steps:
  - command: "make test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          pr_incremental: true
```

## PR comments (SCM token indirection)

Use a Buildkite secret or the `secrets` plugin to expose an SCM token on the
agent (for example as `ENDOR_SCM_TOKEN`). Point `scm_token_env` at the variable
**name**. The plugin passes `--enable-pr-comments=true`, `--scm-pr-id`, and
`--scm-token` to endorctl and never prints the token. This requires a
pull-request build (numeric `BUILDKITE_PULL_REQUEST`) and does not rely on
Buildkite-native OIDC to GitHub.

```yaml
steps:
  - command: "make test"
    env:
      # In real pipelines, inject via the secrets plugin or agent environment.
      ENDOR_SCM_TOKEN: "replace-with-secret"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          enable_pr_comments: true
          scm_token_env: "ENDOR_SCM_TOKEN"
```

## Extra endorctl flags

Use `additional_args` for any endorctl flag not yet exposed as a first-class
plugin option (the string is split on whitespace and appended verbatim).

```yaml
steps:
  - command: "make build"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          additional_args: "--phantom-dependencies=true --tools=true"
```

## Buildkite annotation summary

Enable an annotation card with sanitized scan status.

```yaml
steps:
  - command: "make build"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          annotate: true
```

## Container scan (repository-associated)

Use `scan_container: true` to switch to `endorctl container scan`. For
repository-associated container scans, set `container_scan_path` to the same
path used for source scans.

```yaml
steps:
  - command: "docker build -t ghcr.io/acme/demo:${BUILDKITE_COMMIT} ."
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          scan_dependencies: false
          scan_container: true
          image: "ghcr.io/acme/demo:${BUILDKITE_COMMIT}"
          container_scan_path: "."
          os_reachability: true
```

## Container scan (standalone project with tarball)

For base images or golden images, scan a tarball and persist image versions
using `as_ref`.

```yaml
steps:
  - command: "docker save ghcr.io/acme/base:latest -o /tmp/base-latest.tar"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          scan_dependencies: false
          scan_container: true
          image_tar: "/tmp/base-latest.tar"
          project_name: "golden-base-images"
          as_ref: true
          project_tags: "team=platform,tier=base"
```

## Artifact signing mode

```yaml
steps:
  - command: "make release"
    plugins:
      - endorlabs#v0.1.2:
          mode: "sign"
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          artifact_name: "ghcr.io/acme/demo@sha256:${IMAGE_DIGEST}"
          source_repository_ref: "refs/heads/main"
          certificate_oidc_issuer: "https://token.actions.githubusercontent.com"
          source_repository: "acme/demo"
          source_repository_owner: "acme"
```

## Artifact verify mode

```yaml
steps:
  - command: "make verify-release"
    plugins:
      - endorlabs#v0.1.2:
          mode: "verify"
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          artifact_name: "ghcr.io/acme/demo@sha256:${IMAGE_DIGEST}"
          certificate_oidc_issuer: "https://token.actions.githubusercontent.com"
```

## Soft fail and artifact upload controls

```yaml
steps:
  - command: "make test"
    plugins:
      - endorlabs#v0.1.2:
          namespace: "your-namespace"
          api_key_env: "ENDOR_API_CREDENTIALS_KEY"
          api_secret_env: "ENDOR_API_CREDENTIALS_SECRET"
          output_file: "endor-output.json"
          sarif_file: "endor.sarif"
          annotate: true
          # Informational job: fail_on_policy false ignores exit 128; soft_fail alone does not.
          fail_on_policy: false
          soft_fail: true
          upload_artifacts: true
```
