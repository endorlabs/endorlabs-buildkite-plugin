# Getting started on Buildkite

This guide is the **recommended path for a new Endor Labs customer** wiring the
[endorlabs-buildkite-plugin](https://github.com/endorlabs/endorlabs-buildkite-plugin)
into an existing Buildkite pipeline. Product background:
[docs.endorlabs.com](https://docs.endorlabs.com/).

## What you need first

| Prerequisite | Where |
|--------------|--------|
| Endor Labs tenant (`namespace`) | Endor Labs console / your account team |
| API key + secret (CI) | Endor Labs → API credentials (not `ENDOR_TOKEN` on the same job) |
| Buildkite pipeline with a `command` step | Your application repo |
| Buildkite cluster (agent 3.106.0+ for `secrets:`) | Buildkite → Agents → Clusters |
| Build tools on agents (`bazel`, Node, …) | Cluster image or step `command` — plugin installs **endorctl only** |

## Customer journey (recommended)

### 1. Read setup (5 minutes)

[customer-buildkite-setup.md](customer-buildkite-setup.md) — cluster secrets, **build-tool
prerequisites**, vendoring, annotations, artifacts. Skim [troubleshooting.md](troubleshooting.md)
for PR/namespace pitfalls.

### 2. Vendor the plugin (one-time per repo)

Do **not** start with `endorlabs#v0.1.0` unless agents can clone
`github.com/endorlabs/endorlabs-buildkite-plugin` (often blocked when the app repo
is in a different GitHub org than the plugin).

```bash
# From your application repo root (after cloning endorlabs-buildkite-plugin locally)
ENDORLABS_PLUGIN_SRC=/path/to/endorlabs-buildkite-plugin \
  ./scripts/sync-vendor-endorlabs-plugin.sh
git add .buildkite/vendor/endorlabs-buildkite-plugin
```

Commit the vendor tree and `VENDOR_SOURCE.json` (records the upstream commit).

### 3. Create Buildkite cluster secrets

In **Agents → your cluster → Secrets**, create:

- `ENDOR_NAMESPACE`
- `ENDOR_API_CREDENTIALS_KEY`
- `ENDOR_API_CREDENTIALS_SECRET`

Scope secrets to your pipeline (for example `pipeline_slug: my-app`).

### 4. Add a minimal pipeline step

Your step **`command` runs first**; the plugin **`post-command`** installs
`endorctl`, authenticates, and scans afterward.

Install build tools (Bazel, Node, …) in the agent image or in `command` before the
hook — see [customer-buildkite-setup.md §2](customer-buildkite-setup.md#2-agent-and-cluster-build-tool-prerequisites).

```yaml
secrets:
  - ENDOR_NAMESPACE
  - ENDOR_API_CREDENTIALS_KEY
  - ENDOR_API_CREDENTIALS_SECRET

steps:
  - label: ":hammer: Build"
    command: "make build"   # or your real build/test command
    plugins:
      - ./.buildkite/vendor/endorlabs-buildkite-plugin:
          namespace: "${ENDOR_NAMESPACE}"
          api_key_env: ENDOR_API_CREDENTIALS_KEY
          api_secret_env: ENDOR_API_CREDENTIALS_SECRET
          scan_dependencies: true
          annotate: true
```

**Do not** duplicate `ENDOR_NAMESPACE` under top-level `env:` when it is already
listed under `secrets:` — Buildkite rejects the duplicate.

Optional preflight (fail fast if secrets are missing):

```yaml
  - label: ":endorlabs: Check Endor credentials"
    command: |
      test -n "${ENDOR_NAMESPACE}"
      test -n "${ENDOR_API_CREDENTIALS_KEY}"
      test -n "${ENDOR_API_CREDENTIALS_SECRET}"
```

### 5. Confirm the first build

On [buildkite.com](https://buildkite.com):

1. Open the build → your scan step → **Log** — look for `:endorlabs: Running endorctl scan`.
2. **Annotations** — context defaults to `endorlabs-scan` (or your `annotate_context`).
3. **Artifacts** — if you set `output_file` / `sarif_file`, see
   [customer-buildkite-setup.md §5](customer-buildkite-setup.md#5-annotations-and-job-artifacts).

Policy blocking uses endorctl exit `128` by default (`fail_on_policy: true`).

## After `v0.1.0` is public

When the [Buildkite plugins directory](https://buildkite.com/docs/integrations/buildkite-plugins)
lists this plugin, you may use shorthand `endorlabs#v0.1.1`. Until then, use the full URL
(documented in [troubleshooting.md](troubleshooting.md)):

```yaml
plugins:
  - https://github.com/endorlabs/endorlabs-buildkite-plugin.git#v0.1.1:
      namespace: "${ENDOR_NAMESPACE}"
      ...
```

Vendoring remains valid for air-gapped or cross-org clone constraints.

## What to read next

| Goal | Doc |
|------|-----|
| More YAML patterns (Bazel, secrets, SAST, PR) | [examples.md](examples.md) |
| Secrets, build tools, artifacts, Bazel | [customer-buildkite-setup.md](customer-buildkite-setup.md) |
| Failures (policy, clone, annotations) | [troubleshooting.md](troubleshooting.md) |
| Full option list | [README.md](../README.md) + [plugin.yml](../plugin.yml) |
| Working Buildkite demo | [repro-sandbox](https://github.com/endorlabs/repro-sandbox) |

## Plugin layout vs Buildkite docs

This repository follows the official
[Writing plugins](https://buildkite.com/docs/pipelines/integrations/plugins/writing)
layout:

| Buildkite expects | This repo |
|-------------------|-----------|
| `plugin.yml` with `name`, `description`, `author`, `requirements`, `configuration` | Yes — see [plugin.yml](../plugin.yml) |
| Repository name `*-buildkite-plugin` for `org/plugin` shorthand | `endorlabs-buildkite-plugin` |
| `hooks/` (`post-command` + Windows `.bat`/`.ps1` wrappers) | [hooks/](../hooks/) |
| JSON Schema in `configuration` | `additionalProperties: false` |
| Tests with BATS + plugin-tester | `tests/`, `docker compose run --rm tests` |

Config keys in YAML become `BUILDKITE_PLUGIN_*` env vars on the agent. For a
**vendored** path `./.buildkite/vendor/endorlabs-buildkite-plugin`, the prefix
is longer (`…ENDORLABS_BUILDKITE_PLUGIN_*`); the plugin detects it automatically
(see [customer-buildkite-setup.md](customer-buildkite-setup.md)).

## What is not in this repo

- Hosted Endor credentials or your Buildkite org settings
- Maintainer-only validation pipelines (use [repro-sandbox](https://github.com/endorlabs/repro-sandbox) for E2E demos)
