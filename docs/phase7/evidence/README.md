# Phase 7 — evidence bundle

Store **non-secret** validation artifacts here (or beside this directory in your
internal storage). Do **not** commit API keys, tokens, or scan outputs that
contain sensitive findings unless your policy explicitly allows it.

## Suggested layout

```text
docs/phase7/evidence/
  README.md                 (this file)
  YYYY-MM-DD-build-<id>/
    manifest.md             # table of scenarios + URLs + exit codes
    screenshots/            # Buildkite annotation captures
    excerpts/               # redacted log snippets
```

## Manifest row template

| Step key | Repo | Tags | Raw exit | Effective exit | Annotation context | Artifacts | API check |
|----------|------|------|----------|----------------|--------------------|-----------|-----------|
| p7-defectdojo-baseline | django-DefectDojo | phase7=defectdojo-baseline | 0 | 0 | endorlabs-scan | endor-p7-…json | n/a |

## Notes

- **Raw exit** is what `endorctl` returned; **effective exit** is after
  `fail_on_policy` / `soft_fail` in `hooks/post-command`.
- **Annotation context** should be one of: `endorlabs-scan`, `endorlabs-container`,
  `endorlabs-sign`, `endorlabs-verify`.
