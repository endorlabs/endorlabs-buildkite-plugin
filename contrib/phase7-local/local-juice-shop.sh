#!/usr/bin/env bash
# Maintainer-only: run hooks/post-command with real endorctl in Docker.
# Invoke from repository root: bash contrib/phase7-local/local-juice-shop.sh baseline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

COMPOSE_FILE="$SCRIPT_DIR/docker-compose.phase7-local.yml"
SCENARIO="${1:-baseline}"

PHASE7_PLUGIN_DIR="${PHASE7_PLUGIN_DIR:-$ROOT}"
PHASE7_WORK_DIR="${PHASE7_WORK_DIR:-}"
PHASE7_ENV_FILE="${PHASE7_ENV_FILE:-$ROOT/.env}"

if [[ -z "$PHASE7_WORK_DIR" ]]; then
  echo "phase7: set PHASE7_WORK_DIR to the absolute path of the target git checkout" >&2
  exit 1
fi

_to_docker_path() {
  local p="$1"
  p="${p//\\//}"
  if [[ "$p" =~ ^([A-Za-z]):/(.*)$ ]]; then
    local drive="${BASH_REMATCH[1],,}"
    echo "/${drive}/${BASH_REMATCH[2]}"
  else
    echo "$p"
  fi
}

if command -v cygpath >/dev/null 2>&1; then
  PHASE7_PLUGIN_DIR="$(cygpath -u "$PHASE7_PLUGIN_DIR" 2>/dev/null || echo "$PHASE7_PLUGIN_DIR")"
  PHASE7_WORK_DIR="$(cygpath -u "$PHASE7_WORK_DIR" 2>/dev/null || echo "$PHASE7_WORK_DIR")"
  PHASE7_ENV_FILE="$(cygpath -u "$PHASE7_ENV_FILE" 2>/dev/null || echo "$PHASE7_ENV_FILE")"
fi

export PHASE7_PLUGIN_DIR="$(_to_docker_path "$PHASE7_PLUGIN_DIR")"
export PHASE7_WORK_DIR="$(_to_docker_path "$PHASE7_WORK_DIR")"
export PHASE7_ENV_FILE="$(_to_docker_path "$PHASE7_ENV_FILE")"
export PHASE7_AGENT_IMAGE="${PHASE7_AGENT_IMAGE:-buildkite/agent:3-ubuntu-24.04}"

if [[ ! -f "$PHASE7_ENV_FILE" ]]; then
  echo "phase7: env file not found: $PHASE7_ENV_FILE" >&2
  exit 1
fi

if [[ ! -d "$PHASE7_WORK_DIR/.git" ]]; then
  echo "phase7: work dir must be a git checkout: $PHASE7_WORK_DIR" >&2
  exit 1
fi

TRIMMED_ENV="$(mktemp)"
trap 'rm -f "$TRIMMED_ENV"' EXIT
_PHASE7_ENV_KEYS=(
  ENDOR_API
  ENDOR_API_CREDENTIALS_KEY
  ENDOR_API_CREDENTIALS_SECRET
  ENDOR_NAMESPACE
)
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    keep=false
    for k in "${_PHASE7_ENV_KEYS[@]}"; do
      [[ "$key" == "$k" ]] && keep=true && break
    done
    [[ "$keep" == true ]] || continue
    val="${BASH_REMATCH[2]}"
    val="${val//$'\r'/}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    printf '%s=%s\n' "$key" "$val" >>"$TRIMMED_ENV"
  fi
done <"$PHASE7_ENV_FILE"
export PHASE7_ENV_FILE="$TRIMMED_ENV"

ENDOR_NAMESPACE="$(grep -E '^ENDOR_NAMESPACE=' "$TRIMMED_ENV" | head -1 | cut -d= -f2- || true)"
if [[ -z "$ENDOR_NAMESPACE" ]]; then
  echo "phase7: ENDOR_NAMESPACE missing in env file" >&2
  exit 1
fi

unset \
  BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES \
  BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS \
  BUILDKITE_PLUGIN_ENDORLABS_SCAN_AI_MODELS \
  BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER \
  BUILDKITE_PLUGIN_ENDORLABS_SCAN_PATH \
  BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE \
  BUILDKITE_PLUGIN_ENDORLABS_SOFT_FAIL \
  BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE \
  BUILDKITE_PLUGIN_ENDORLABS_IMAGE \
  BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE

export BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE="$ENDOR_NAMESPACE"
export BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV="ENDOR_API_CREDENTIALS_KEY"
export BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV="ENDOR_API_CREDENTIALS_SECRET"
export BUILDKITE_PLUGIN_ENDORLABS_SCAN_PATH="."
export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE="true"
export BUILDKITE_PLUGIN_ENDORLABS_ADDITIONAL_ARGS="${BUILDKITE_PLUGIN_ENDORLABS_ADDITIONAL_ARGS:---bypass-host-check}"

case "$SCENARIO" in
  baseline)
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES="true"
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS="true"
    export BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE="endor-local-deps-tools.json"
    ;;
  ai-models)
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES="true"
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS="true"
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_AI_MODELS="true"
    export BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE="endor-local-ai-models.json"
    ;;
  soft-fail)
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES="true"
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS="true"
    export BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE="endor-local-soft-fail.json"
    export BUILDKITE_PLUGIN_ENDORLABS_SOFT_FAIL="true"
    export BUILDKITE_PLUGIN_ENDORLABS_FAIL_ON_POLICY="false"
    ;;
  container)
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER="true"
    export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES="false"
    export BUILDKITE_PLUGIN_ENDORLABS_IMAGE="alpine:3.19"
    export BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE="endor-local-container.json"
    ;;
  *)
    echo "phase7: unknown scenario '$SCENARIO' (baseline|ai-models|soft-fail|container)" >&2
    exit 1
    ;;
esac

LOG_DIR="$ROOT/.phase7-logs"
mkdir -p "$LOG_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/${SCENARIO}-${STAMP}.log"

echo "phase7: scenario=$SCENARIO workdir=$PHASE7_WORK_DIR log=$LOG_FILE"

DOCKER_SOCK=""
if [[ -S /var/run/docker.sock ]]; then
  DOCKER_SOCK="/var/run/docker.sock:/var/run/docker.sock"
fi

EXTRA_VOLUMES=()
if [[ -n "$DOCKER_SOCK" && "$SCENARIO" == "container" ]]; then
  EXTRA_VOLUMES=(-v "$DOCKER_SOCK")
fi

set +e
docker compose -f "$COMPOSE_FILE" run --rm \
  "${EXTRA_VOLUMES[@]}" \
  -e BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE \
  -e BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV \
  -e BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV \
  -e BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES \
  -e BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS \
  -e BUILDKITE_PLUGIN_ENDORLABS_SCAN_AI_MODELS \
  -e BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER \
  -e BUILDKITE_PLUGIN_ENDORLABS_SCAN_PATH \
  -e BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE \
  -e BUILDKITE_PLUGIN_ENDORLABS_SOFT_FAIL \
  -e BUILDKITE_PLUGIN_ENDORLABS_FAIL_ON_POLICY \
  -e BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE \
  -e BUILDKITE_PLUGIN_ENDORLABS_ADDITIONAL_ARGS \
  -e BUILDKITE_PLUGIN_ENDORLABS_IMAGE \
  -e BUILDKITE_BRANCH \
  phase7 \
  "set -euo pipefail
   set -a && . /run/secrets/endor.env && set +a
   export PATH=\"/usr/local/bin:\$PATH\"
   command -v git curl bash buildkite-agent >/dev/null
   cd /work
   bash /plugin/hooks/post-command" \
  2>&1 | tee "$LOG_FILE"
HOOK_EXIT="${PIPESTATUS[0]}"
set -e

REDACT_LOG="$LOG_DIR/${SCENARIO}-${STAMP}.redacted.log"
sed -E \
  -e 's/(api[_-]?key|api[_-]?secret|credentials|token|authorization)[^[:space:]]*/\1=[REDACTED]/gi' \
  -e 's/endr\+[A-Za-z0-9]+/[REDACTED]/g' \
  -e 's/sk-[A-Za-z0-9]+/[REDACTED]/g' \
  "$LOG_FILE" >"$REDACT_LOG" || cp "$LOG_FILE" "$REDACT_LOG"

echo "--- phase7 excerpt (redacted) ---"
grep -E 'endorlabs|endorctl|annotate|soft_fail|dependencies|tools|ai-models|container scan|exit code|policy|~~~' "$REDACT_LOG" | tail -40 || true

OUTPUT_FILE="${BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE:-}"
if [[ -n "$OUTPUT_FILE" ]]; then
  if [[ -f "$PHASE7_WORK_DIR/$OUTPUT_FILE" ]]; then
    echo "phase7: output file present: $PHASE7_WORK_DIR/$OUTPUT_FILE"
  else
    echo "phase7: output file not found on host at $PHASE7_WORK_DIR/$OUTPUT_FILE (check container /work)" >&2
  fi
fi

echo "phase7: hook exit code=$HOOK_EXIT"
exit "$HOOK_EXIT"
