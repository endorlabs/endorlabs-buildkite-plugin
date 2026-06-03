# Release checklist

Steps before publishing articles, the Buildkite plugin directory listing, or external launch announcements.

## Code and tests

1. Merge plugin changes on `main`; run `docker compose run --rm tests` (52 BATS tests).
2. Customer docs sanity: [getting-started.md](getting-started.md) path matches [customer-buildkite-setup.md](customer-buildkite-setup.md) and [examples.md](examples.md).
3. Local **endorctl** gate: `endorctl scan --ai-sast --secrets --sast` (exit 0, no secrets).

## GitHub repository (org settings)

4. Make the repository **public**.
5. **Website:** keep `https://docs.endorlabs.com/` (canonical product docs).
6. **About description:** e.g. *Buildkite plugin for Endor Labs — run endorctl in CI to ship secure code with SCA, SAST, secrets, containers, and policy gating.*
7. **Topics:** `buildkite-plugin`, `buildkite`, `security`, `endorlabs`, `sca`, `sast`.
8. Upload **social preview** image (Endor logo, ≥640×640) under repository Settings → General.
9. Tag **`v0.1.0`** and publish a GitHub Release (body mirrors [CHANGELOG.md](../CHANGELOG.md)).

## Hosted validation (repro-sandbox)

10. Sync vendored plugin: `ENDORLABS_PLUGIN_SRC=/path/to/endorlabs-buildkite-plugin ./scripts/sync-vendor-endorlabs-plugin.sh` in [repro-sandbox](https://github.com/endorlabs/repro-sandbox); push `dev`.
11. Run green **Buildkite App** cycles on repro (default `pipeline.yml` on push). Optionally upload `pipeline.layered-scans.yml` or `pipeline.juice-shop.yml` for internal QA.

## Buildkite directory

12. Confirm `plugin.yml` `name` and `description` match the About copy.
13. Wait for **Sunday UTC** directory sync after the repo is public and tagged.
14. Optional: [buildkite/emojis PR #702](https://github.com/buildkite/emojis/pull/702) for `:endorlabs:` glyph in the UI (labels already use `:endorlabs:`; not a release blocker).

## Publish

15. Publish blog/docs article and customer announcement after steps above are green.
