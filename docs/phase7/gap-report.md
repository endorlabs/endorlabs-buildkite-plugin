# Phase 7 — gap report (living document)

This file records **repo-specific edge cases**, **product prerequisites**, and
**plugin limits** discovered while running the Phase 7 matrix. Update it after
each validation wave.

## Harness status

The following are in-repo **without** requiring live Buildkite / Endor execution:

- `.buildkite/pipeline.phase7.yml` — parametrized matrix (placeholder substitution).
- `scripts/phase7/run-repo-matrix.sh` — config check, render, upload helper.
- `docs/phase7-validation.md` — runbook and acceptance notes.
- `docs/phase7/evidence/README.md` — evidence bundle template.

### Gaps requiring human follow-up

| Item | Rationale |
|------|-----------|
| Buildkite UI annotation screenshots | Requires a manual matrix run on your agents. |
| Endor API confirmation of scans | Requires tenant access and your API workflow. |
| `mode: sign` / `mode: verify` success path | Smoke steps use placeholder artifact coordinates and `soft_fail: true`; real signing needs tenant + artifact configuration per `github-action` `src/sign.ts`. |
| Windows-only Buildkite agents | Plugin and Phase 7 pipeline target bash/Linux; Windows agents are out of scope for this matrix. |
| `p7-mongo-additional-args` | Uses `additional_args: "--log-level=warn"` as a safe argv passthrough smoke; it does not assert a unique side effect in logs. |

### Phase 6 follow-through (optional)

- **Annotation formatting tuning** (`PLAN.md` Phase 6) remains open until real
  `endorctl` JSON/SARIF samples drive copy/HTML tweaks.

### Recommended next phases

- Publish a versioned plugin reference (`endorlabs/endorlabs-buildkite-plugin#v…`)
  so pipelines do not depend on `file://` paths on agents.
- Add a trimmed “smoke” Phase 7 pipeline for PR CI on this repo (optional),
  gated on secrets, if you want continuous real scans (cost/latency tradeoff).
