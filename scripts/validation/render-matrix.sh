#!/usr/bin/env bash
# Maintainer-only: render the parametrized validation matrix and optionally upload.
#
# Usage:
#   scripts/validation/render-matrix.sh --check-only
#   scripts/validation/render-matrix.sh --render /tmp/validation-rendered.yml
#   scripts/validation/render-matrix.sh --upload   # runs buildkite-agent pipeline upload
#
# Configuration: source scripts/validation/paths.env (gitignored) or export the
# same variables before invoking this script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${ROOT}/.buildkite/validation/matrix.yml"
OUT_DEFAULT="${ROOT}/.buildkite/validation/matrix.resolved.yml"

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

if [[ -f "${ROOT}/scripts/validation/paths.env" ]]; then
  # shellcheck source=/dev/null
  source "${ROOT}/scripts/validation/paths.env"
fi

required_vars=(
  ENDORLABS_BUILDKITE_PLUGIN_REF
  VALIDATION_REPO_DEFECTDOJO
  VALIDATION_REPO_AGENT
  VALIDATION_REPO_MONGO
  VALIDATION_REPO_SPRING_BOOT
  VALIDATION_REPO_JUICE_SHOP
  ENDOR_NAMESPACE
)

missing=()
for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    missing+=("$v")
  fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "validation: missing required configuration: ${missing[*]}" >&2
  echo "validation: copy scripts/validation/paths.env.example to scripts/validation/paths.env and fill values, or export these variables." >&2
  exit 1
fi

substitute() {
  local content
  content="$(cat "$TEMPLATE")"
  content="${content//__ENDORLABS_BUILDKITE_PLUGIN_REF__/${ENDORLABS_BUILDKITE_PLUGIN_REF}}"
  content="${content//__VALIDATION_REPO_DEFECTDOJO__/${VALIDATION_REPO_DEFECTDOJO}}"
  content="${content//__VALIDATION_REPO_AGENT__/${VALIDATION_REPO_AGENT}}"
  content="${content//__VALIDATION_REPO_MONGO__/${VALIDATION_REPO_MONGO}}"
  content="${content//__VALIDATION_REPO_SPRING_BOOT__/${VALIDATION_REPO_SPRING_BOOT}}"
  content="${content//__VALIDATION_REPO_JUICE_SHOP__/${VALIDATION_REPO_JUICE_SHOP}}"
  content="${content//__ENDOR_NAMESPACE__/${ENDOR_NAMESPACE}}"
  printf '%s\n' "$content"
}

case "$MODE" in
  check-only)
    echo "validation: configuration OK (${#required_vars[@]} variables set)."
    ;;
  render)
    substitute >"$OUT_PATH"
    echo "validation: wrote $OUT_PATH"
    ;;
  upload)
    if ! command -v buildkite-agent >/dev/null 2>&1; then
      echo "validation: buildkite-agent not found on PATH" >&2
      exit 1
    fi
    OUT_PATH="${OUT_PATH:-$OUT_DEFAULT}"
    substitute >"$OUT_PATH"
    echo "validation: uploading $OUT_PATH"
    buildkite-agent pipeline upload "$OUT_PATH"
    ;;
esac
