#!/usr/bin/env bash
# Configure Buildkite org env and pipeline secrets from a local .env (never commit .env).
#
# Usage:
#   ./scripts/setup-buildkite-secrets.sh --dry-run --org tim-gowan --pipeline repro-sandbox
#   ./scripts/setup-buildkite-secrets.sh --org tim-gowan --pipeline repro-sandbox
#
# Required in .env (or environment):
#   BUILDKITE_API_TOKEN, ENDOR_NAMESPACE, ENDOR_API_CREDENTIALS_KEY, ENDOR_API_CREDENTIALS_SECRET
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${BUILDKITE_SETUP_ENV_FILE:-$ROOT/.env}"
DRY_RUN=false
ORG=""
PIPELINE=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --org) ORG="${2:?}"; shift ;;
    --pipeline) PIPELINE="${2:?}"; shift ;;
    --env-file) ENV_FILE="${2:?}"; shift ;;
    -h|--help)
      sed -n '1,12p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -z "$ORG" || -z "$PIPELINE" ]]; then
  echo "usage: $0 [--dry-run] --org ORG_SLUG --pipeline PIPELINE_SLUG [--env-file PATH]" >&2
  exit 2
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "setup-buildkite-secrets: env file not found: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

for v in BUILDKITE_API_TOKEN ENDOR_NAMESPACE ENDOR_API_CREDENTIALS_KEY ENDOR_API_CREDENTIALS_SECRET; do
  if [[ -z "${!v:-}" ]]; then
    echo "setup-buildkite-secrets: missing $v in $ENV_FILE" >&2
    exit 1
  fi
done

api() {
  local method="$1"
  local path="$2"
  shift 2
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] curl -X $method https://api.buildkite.com/v2/${path}"
    return 0
  fi
  curl -fsS -X "$method" \
    -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "https://api.buildkite.com/v2/${path}" \
    "$@"
}

echo "setup-buildkite-secrets: org=${ORG} pipeline=${PIPELINE}"

# Org environment variable (non-secret namespace)
api PATCH "organizations/${ORG}" \
  -d "$(jq -n --arg ns "$ENDOR_NAMESPACE" '{env: {ENDOR_NAMESPACE: $ns}}')" \
  2>/dev/null || echo "note: org env PATCH may require GraphQL or UI; set ENDOR_NAMESPACE on pipeline manually if this fails"

# Pipeline secrets (Buildkite REST: create/update via pipelines API)
# https://buildkite.com/docs/apis/rest-api/pipelines
for key in ENDOR_API_CREDENTIALS_KEY ENDOR_API_CREDENTIALS_SECRET; do
  val="${!key}"
  payload="$(jq -n --arg k "$key" --arg v "$val" '{key: $k, value: $v}')"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] would set pipeline secret: $key"
  else
    if ! api POST "organizations/${ORG}/pipelines/${PIPELINE}/secrets" -d "$payload" 2>/dev/null; then
      echo "setup-buildkite-secrets: POST secret $key failed; set in Buildkite UI (Secrets → $key)" >&2
    fi
  fi
done

echo "setup-buildkite-secrets: done (verify in Buildkite UI → Pipeline → Settings → Environment/Secrets)"
