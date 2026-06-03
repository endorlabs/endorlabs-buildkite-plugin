# Security

## Reporting vulnerabilities

If you believe you have found a security issue in this plugin, report it through
your Endor Labs support channel or contact [Endor Labs](https://endorlabs.com)
rather than opening a public issue with exploit details.

## Using credentials safely

- **Never** commit API keys, secrets, bearer tokens, or `.env` files to git.
- Use `api_key_env` and `api_secret_env` so pipeline YAML only references the
  **names** of environment variables; store values in Buildkite secrets, agent
  hooks, or your secret manager.
- The plugin exports credentials into the environment for `endorctl` and does
  **not** pass `--api-key` / `--api-secret` on the command line (avoids echo in
  build logs and process listings).
- SCM tokens for PR comments use `scm_token_env` the same way; values are never
  printed in plugin logs.
- Do not set `ENDOR_TOKEN` on the agent when using API-key mode; conflicting auth
  causes endorctl exit code 4.
- `soft_fail: true` does not bypass policy exit `128` when `fail_on_policy` is
  true (default); use `fail_on_policy: false` only on non-gating jobs.

## Scan outputs and artifacts

`output_file`, `sarif_file`, and uploaded Buildkite artifacts may contain
vulnerable dependency data, code locations, or policy findings. Treat them as
**sensitive**; restrict artifact retention and log access in your organization.

Buildkite annotations (`annotate: true`) publish only a sanitized summary (status
and optional finding count), not raw scan JSON or credentials.
