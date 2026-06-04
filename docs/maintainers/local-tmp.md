# Local maintainer work (`.tmp/`)

All **non-shipping** maintainer tooling and artifacts live under **`.tmp/`** at the repository root. That directory is **gitignored** — nothing inside it is committed.

## Rule

| Location | Allowed content |
|----------|-----------------|
| **`scripts/`** | Repo-wide, committable automation only (e.g. `sync-vendor-endorlabs-plugin.sh`). |
| **`.tmp/scripts/`** | Download helpers, annotation mockups, CSV/JSON validation, one-off experiments. |
| **`.tmp/exports/`** | Endor CSV exports from the app/API. |
| **`.tmp/validation/`** | Buildkite `output_file` JSON downloaded for inspection. |
| **`.tmp/mockups/`** | Generated HTML previews. |

**Do not** add validation, download, or mockup scripts under `scripts/`. If you find any there, move them to `.tmp/scripts/`.

## Layout

```
.tmp/
  scripts/
    download-repro-scan-artifacts.ps1   # BUILDKITE_API_TOKEN in .env
    validate-annotation-mapping.bash    # needs jq + lib/endorctl.bash
    generate-annotation-mockup.bash     # opens .tmp/mockups/annotation-preview.html
    analyze-findings-csv.bash           # needs python; reads .tmp/exports/*.csv
  exports/                              # CSV exports
  validation/build-<n>/                 # per-build scan JSON
  mockups/                              # HTML previews
  mockup-fixtures/                      # fixture JSON for mockup script
```

## Commands (from repo root)

```powershell
# Download repro-sandbox scan artifacts (default build 51)
powershell -NoProfile -File .tmp/scripts/download-repro-scan-artifacts.ps1 -BuildNumber 51
```

```bash
# Validate annotation filters against downloaded JSON
bash .tmp/scripts/validate-annotation-mapping.bash

# HTML mockup of annotate output
bash .tmp/scripts/generate-annotation-mockup.bash

# Summarize a findings CSV export
bash .tmp/scripts/analyze-findings-csv.bash
```

Also keep secrets in **`.env`** (gitignored), never in `.tmp/` or the tree.
