#!/usr/bin/env bash
# Phase 7 — render the parametrized Buildkite pipeline and optionally upload it.
#
# Usage:
#   scripts/phase7/run-repo-matrix.sh --check-only
#   scripts/phase7/run-repo-matrix.sh --render /tmp/phase7-rendered.yml
#   scripts/phase7/run-repo-matrix.sh --upload   # runs buildkite-agent pipeline upload
#
# Configuration: source scripts/phase7/phase7.paths.env (gitignored) or set the
# same variables in the environment before invoking this script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${ROOT}/.buildkite/pipeline.phase7.yml"
OUT_DEFAULT="${ROOT}/.buildkite/pipeline.phase7.resolved.yml"

MODE="check-only"
OUT_PATH=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --check-only) MODE="check-only" ;;
    --render)
      MODE="render"
      OUT_PATH="${2:?--render requires output path}"
      shift
      ;;
    --upload) MODE="upload" ;;
    -h|--help)
      sed -n '1,25p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -f "${ROOT}/scripts/phase7/phase7.paths.env" ]]; then
  # shellcheck source=/dev/null
  source "${ROOT}/scripts/phase7/phase7.paths.env"
fi

required_vars=(
  ENDORLABS_BUILDKITE_PLUGIN_REF
  PHASE7_REPO_DEFECTDOJO
  PHASE7_REPO_AGENT
  PHASE7_REPO_MONGO
  PHASE7_REPO_SPRING_BOOT
  PHASE7_REPO_JUICE_SHOP
  ENDOR_NAMESPACE
)

missing=()
for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    missing+=("$v")
  fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "phase7: missing required configuration: ${missing[*]}" >&2
  echo "phase7: copy scripts/phase7/phase7.paths.env.example to scripts/phase7/phase7.paths.env and fill values, or export these variables." >&2
  exit 1
fi

substitute() {
  local content
  content="$(cat "$TEMPLATE")"
  content="${content//__ENDORLABS_BUILDKITE_PLUGIN_REF__/${ENDORLABS_BUILDKITE_PLUGIN_REF}}"
  content="${content//__PHASE7_REPO_DEFECTDOJO__/${PHASE7_REPO_DEFECTDOJO}}"
  content="${content//__PHASE7_REPO_AGENT__/${PHASE7_REPO_AGENT}}"
  content="${content//__PHASE7_REPO_MONGO__/${PHASE7_REPO_MONGO}}"
  content="${content//__PHASE7_REPO_SPRING_BOOT__/${PHASE7_REPO_SPRING_BOOT}}"
  content="${content//__PHASE7_REPO_JUICE_SHOP__/${PHASE7_REPO_JUICE_SHOP}}"
  content="${content//__ENDOR_NAMESPACE__/${ENDOR_NAMESPACE}}"
  printf '%s\n' "$content"
}

case "$MODE" in
  check-only)
    echo "phase7: configuration OK (${#required_vars[@]} variables set)."
    ;;
  render)
    substitute >"$OUT_PATH"
    echo "phase7: wrote $OUT_PATH"
    ;;
  upload)
    if ! command -v buildkite-agent >/dev/null 2>&1; then
      echo "phase7: buildkite-agent not found on PATH" >&2
      exit 1
    fi
    OUT_PATH="${OUT_PATH:-$OUT_DEFAULT}"
    substitute >"$OUT_PATH"
    echo "phase7: uploading $OUT_PATH"
    buildkite-agent pipeline upload "$OUT_PATH"
    ;;
esac
