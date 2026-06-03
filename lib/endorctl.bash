#!/bin/bash

# endorctl install/auth/scan helpers for the Endor Labs Buildkite plugin.
#
# Public functions (called from hooks/post-command):
#   configure_endorctl  - resolve config defaults, validate inputs
#   install_endorctl    - download + checksum-verify endorctl (or skip)
#   configure_auth      - export ENDOR_* credentials from env indirection
#   run_scan            - build args, exec endorctl scan
#
# Notes:
# - Secrets are exported into the environment for endorctl to read; we
#   intentionally do NOT pass --api-key/--api-secret on the CLI to avoid
#   leaking values through Buildkite's command echo / process listings.
# - Buildkite context (branch, PR id, base branch) is mapped to endorctl
#   flags rather than ENDOR_SCAN_* env vars so the BATS stubs match the
#   exact argv users would see in build logs.

ENDORCTL_DEFAULT_API="https://api.endorlabs.com"

# Fill in derived defaults and validate combinations.
function configure_endorctl() {
  ENDOR_PLUGIN_MODE="$(plugin_read_config MODE "scan")"
  ENDOR_PLUGIN_NAMESPACE="$(plugin_read_config NAMESPACE)"
  # Buildkite may interpolate namespace: "${ENDOR_NAMESPACE}" before cluster secrets
  # apply; fall back to the job env var (secrets: or pipeline env).
  if [[ -z "$ENDOR_PLUGIN_NAMESPACE" ]]; then
    ENDOR_PLUGIN_NAMESPACE="${ENDOR_NAMESPACE:-}"
  fi
  ENDOR_PLUGIN_API="$(plugin_read_config API)"
  ENDOR_PLUGIN_SCAN_PATH="$(plugin_read_config SCAN_PATH)"
  ENDOR_PLUGIN_SCAN_DEPENDENCIES="$(plugin_read_config SCAN_DEPENDENCIES "true")"
  ENDOR_PLUGIN_SCAN_SECRETS="$(plugin_read_config SCAN_SECRETS "false")"
  ENDOR_PLUGIN_SCAN_SAST="$(plugin_read_config SCAN_SAST "false")"
  ENDOR_PLUGIN_SCAN_GIT_LOGS="$(plugin_read_config SCAN_GIT_LOGS "false")"
  ENDOR_PLUGIN_SCAN_GITHUB_ACTIONS="$(plugin_read_config SCAN_GITHUB_ACTIONS "false")"
  ENDOR_PLUGIN_SCAN_AI_MODELS="$(plugin_read_config SCAN_AI_MODELS "false")"
  ENDOR_PLUGIN_SCAN_TOOLS="$(plugin_read_config SCAN_TOOLS "false")"
  ENDOR_PLUGIN_SCAN_PACKAGE="$(plugin_read_config SCAN_PACKAGE "false")"
  ENDOR_PLUGIN_SCAN_CONTAINER="$(plugin_read_config SCAN_CONTAINER "false")"
  ENDOR_PLUGIN_PHANTOM_DEPENDENCIES="$(plugin_read_config PHANTOM_DEPENDENCIES "false")"
  ENDOR_PLUGIN_DISABLE_CODE_SNIPPET_STORAGE="$(plugin_read_config DISABLE_CODE_SNIPPET_STORAGE "false")"
  ENDOR_PLUGIN_USE_BAZEL="$(plugin_read_config USE_BAZEL "false")"
  ENDOR_PLUGIN_BAZEL_INCLUDE_TARGETS="$(plugin_read_config BAZEL_INCLUDE_TARGETS)"
  ENDOR_PLUGIN_BAZEL_EXCLUDE_TARGETS="$(plugin_read_config BAZEL_EXCLUDE_TARGETS)"
  ENDOR_PLUGIN_BAZEL_TARGETS_QUERY="$(plugin_read_config BAZEL_TARGETS_QUERY)"
  ENDOR_PLUGIN_PROJECT_NAME="$(plugin_read_config PROJECT_NAME)"
  ENDOR_PLUGIN_IMAGE="$(plugin_read_config IMAGE)"
  ENDOR_PLUGIN_IMAGE_TAR="$(plugin_read_config IMAGE_TAR)"
  ENDOR_PLUGIN_AS_REF="$(plugin_read_config AS_REF "false")"
  ENDOR_PLUGIN_OS_REACHABILITY="$(plugin_read_config OS_REACHABILITY "false")"
  ENDOR_PLUGIN_PROJECT_TAGS="$(plugin_read_config PROJECT_TAGS)"
  ENDOR_PLUGIN_CONTAINER_SCAN_PATH="$(plugin_read_config CONTAINER_SCAN_PATH ".")"
  ENDOR_PLUGIN_PROFILING_DATA_DIR="$(plugin_read_config PROFILING_DATA_DIR)"
  ENDOR_PLUGIN_ARTIFACT_NAME="$(plugin_read_config ARTIFACT_NAME)"
  ENDOR_PLUGIN_CERTIFICATE_OIDC_ISSUER="$(plugin_read_config CERTIFICATE_OIDC_ISSUER)"
  ENDOR_PLUGIN_CERTIFICATE_IDENTITY="$(plugin_read_config CERTIFICATE_IDENTITY)"
  ENDOR_PLUGIN_SOURCE_REPOSITORY_REF="$(plugin_read_config SOURCE_REPOSITORY_REF)"
  ENDOR_PLUGIN_SOURCE_REPOSITORY="$(plugin_read_config SOURCE_REPOSITORY)"
  ENDOR_PLUGIN_SOURCE_REPOSITORY_OWNER="$(plugin_read_config SOURCE_REPOSITORY_OWNER)"
  ENDOR_PLUGIN_SOURCE_REPOSITORY_DIGEST="$(plugin_read_config SOURCE_REPOSITORY_DIGEST)"
  ENDOR_PLUGIN_BUILD_CONFIG_NAME="$(plugin_read_config BUILD_CONFIG_NAME)"
  ENDOR_PLUGIN_BUILD_CONFIG_DIGEST="$(plugin_read_config BUILD_CONFIG_DIGEST)"
  ENDOR_PLUGIN_RUNNER_ENVIRONMENT="$(plugin_read_config RUNNER_ENVIRONMENT)"
  ENDOR_PLUGIN_LOG_LEVEL="$(plugin_read_config LOG_LEVEL "info")"
  ENDOR_PLUGIN_LOG_VERBOSE="$(plugin_read_config LOG_VERBOSE "false")"
  ENDOR_PLUGIN_OUTPUT_TYPE="$(plugin_read_config OUTPUT_TYPE "json")"
  ENDOR_PLUGIN_TAGS="$(plugin_read_config TAGS)"
  ENDOR_PLUGIN_SARIF_FILE="$(plugin_read_config SARIF_FILE)"
  ENDOR_PLUGIN_OUTPUT_FILE="$(plugin_read_config OUTPUT_FILE)"
  ENDOR_PLUGIN_EXIT_ON_POLICY_WARNING="$(plugin_read_config EXIT_ON_POLICY_WARNING "false")"
  ENDOR_PLUGIN_ADDITIONAL_ARGS="$(plugin_read_config ADDITIONAL_ARGS)"
  ENDOR_PLUGIN_ENDORCTL_VERSION="$(plugin_read_config ENDORCTL_VERSION)"
  ENDOR_PLUGIN_ENDORCTL_CHECKSUM="$(plugin_read_config ENDORCTL_CHECKSUM)"
  ENDOR_PLUGIN_ENDORCTL_SKIP_INSTALL="$(plugin_read_config ENDORCTL_SKIP_INSTALL "false")"
  ENDOR_PLUGIN_API_KEY_ENV="$(plugin_read_config API_KEY_ENV)"
  ENDOR_PLUGIN_API_SECRET_ENV="$(plugin_read_config API_SECRET_ENV)"
  ENDOR_PLUGIN_AWS_ROLE_ARN="$(plugin_read_config AWS_ROLE_ARN)"
  ENDOR_PLUGIN_ENABLE_AZURE_MANAGED_IDENTITY="$(plugin_read_config ENABLE_AZURE_MANAGED_IDENTITY "false")"
  ENDOR_PLUGIN_GCP_SERVICE_ACCOUNT="$(plugin_read_config GCP_SERVICE_ACCOUNT)"
  ENDOR_PLUGIN_ANNOTATE="$(plugin_read_config ANNOTATE "false")"
  ENDOR_PLUGIN_ANNOTATE_CONTEXT="$(plugin_read_config ANNOTATE_CONTEXT)"
  ENDOR_PLUGIN_ANNOTATE_SCOPE="$(plugin_read_config ANNOTATE_SCOPE "build")"
  ENDOR_PLUGIN_ANNOTATE_FINDINGS_LIMIT="$(plugin_read_config ANNOTATE_FINDINGS_LIMIT "15")"
  ENDOR_PLUGIN_PR="$(plugin_read_config PR)"
  ENDOR_PLUGIN_PR_BASELINE="$(plugin_read_config PR_BASELINE)"
  ENDOR_PLUGIN_PR_INCREMENTAL="$(plugin_read_config PR_INCREMENTAL "false")"
  ENDOR_PLUGIN_ENABLE_PR_COMMENTS="$(plugin_read_config ENABLE_PR_COMMENTS "false")"
  ENDOR_PLUGIN_SCM_TOKEN_ENV="$(plugin_read_config SCM_TOKEN_ENV)"
  ENDOR_PLUGIN_SOFT_FAIL="$(plugin_read_config SOFT_FAIL "false")"
  ENDOR_PLUGIN_FAIL_ON_POLICY="$(plugin_read_config FAIL_ON_POLICY "true")"
  ENDOR_PLUGIN_UPLOAD_ARTIFACTS="$(plugin_read_config UPLOAD_ARTIFACTS "false")"
  ENDOR_PLUGIN_ARTIFACT_PATHS="$(plugin_read_config ARTIFACT_PATHS)"

  # When consumers set output paths, upload to Buildkite job artifacts unless explicitly disabled.
  if ! plugin_config_exists UPLOAD_ARTIFACTS; then
    if [[ -n "$ENDOR_PLUGIN_OUTPUT_FILE" || -n "$ENDOR_PLUGIN_SARIF_FILE" ]]; then
      ENDOR_PLUGIN_UPLOAD_ARTIFACTS="true"
    fi
  fi

  if [[ -z "$ENDOR_PLUGIN_NAMESPACE" ]]; then
    log_fatal "endorlabs plugin: 'namespace' is required"
  fi

  if [[ -n "$ENDOR_PLUGIN_ENDORCTL_VERSION" && -z "$ENDOR_PLUGIN_ENDORCTL_CHECKSUM" ]]; then
    log_fatal "endorlabs plugin: 'endorctl_checksum' is required when 'endorctl_version' is pinned"
  fi
}

# Resolve API key + secret from env indirection (api_key_env / api_secret_env)
# or fall back to ENDOR_API_CREDENTIALS_KEY / ENDOR_API_CREDENTIALS_SECRET if
# the user pre-exported them on the agent.
function configure_auth() {
  # Cloud keyless auth modes bypass API key/secret requirements.
  if [[ -n "${ENDOR_PLUGIN_AWS_ROLE_ARN:-}" ]]; then
    return 0
  fi
  if [[ "${ENDOR_PLUGIN_ENABLE_AZURE_MANAGED_IDENTITY:-false}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${ENDOR_PLUGIN_GCP_SERVICE_ACCOUNT:-}" ]]; then
    return 0
  fi

  local key_var="$ENDOR_PLUGIN_API_KEY_ENV"
  local secret_var="$ENDOR_PLUGIN_API_SECRET_ENV"
  local key="" secret=""

  if [[ -n "$key_var" ]]; then
    key="${!key_var:-}"
  fi
  if [[ -n "$secret_var" ]]; then
    secret="${!secret_var:-}"
  fi

  # Fall back to pre-set ENDOR_API_CREDENTIALS_* if env indirection not used.
  : "${key:=${ENDOR_API_CREDENTIALS_KEY:-}}"
  : "${secret:=${ENDOR_API_CREDENTIALS_SECRET:-}}"

  if [[ -z "$key" || -z "$secret" ]]; then
    log_fatal "endorlabs plugin: API credentials not found. Set api_key_env and api_secret_env (or pre-export ENDOR_API_CREDENTIALS_KEY and ENDOR_API_CREDENTIALS_SECRET)."
  fi

  export ENDOR_API_CREDENTIALS_KEY="$key"
  export ENDOR_API_CREDENTIALS_SECRET="$secret"
  # Avoid endorctl exit 4 when agents also export bearer token env vars.
  unset ENDOR_TOKEN
}

# Detect endorctl-compatible OS string (linux | macos | windows).
function _endorctl_os() {
  case "${OSTYPE:-$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')}" in
    linux*)   echo "linux" ;;
    darwin*)  echo "macos" ;;
    msys*|cygwin*|win32*|mingw*) echo "windows" ;;
    *)
      case "$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')" in
        linux*)  echo "linux" ;;
        darwin*) echo "macos" ;;
        *)       echo "linux" ;;
      esac
      ;;
  esac
}

# Detect endorctl-compatible arch (amd64 | arm64).
function _endorctl_arch() {
  case "$(uname -m 2>/dev/null)" in
    x86_64|amd64)  echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)             echo "amd64" ;;
  esac
}

# Compute sha256 of $1 using whichever tool is available.
function _sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    log_fatal "endorlabs plugin: neither sha256sum nor shasum is available"
  fi
}

# Resolve install dir; honours BUILDKITE_PLUGIN_ENDORLABS_INSTALL_DIR for tests.
function _endorctl_install_dir() {
  local dir
  dir="$(plugin_read_config INSTALL_DIR)"
  if [[ -z "$dir" ]]; then
    dir="${TMPDIR:-/tmp}/endorlabs-buildkite-plugin"
  fi
  echo "$dir"
}

# Download endorctl + verify checksum. No-op if endorctl already on PATH
# (and no specific version was requested), or if endorctl_skip_install=true.
function install_endorctl() {
  if [[ "$ENDOR_PLUGIN_ENDORCTL_SKIP_INSTALL" == "true" ]]; then
    log_group ":endorlabs: Skipping endorctl install (endorctl_skip_install=true)"
    return 0
  fi

  if [[ -z "$ENDOR_PLUGIN_ENDORCTL_VERSION" ]] && command -v endorctl >/dev/null 2>&1; then
    log_group ":endorlabs: Using endorctl already on PATH ($(command -v endorctl))"
    return 0
  fi

  local api="${ENDOR_PLUGIN_API:-$ENDORCTL_DEFAULT_API}"
  local os arch version checksum install_dir bin_name url tmp_file
  os="$(_endorctl_os)"
  arch="$(_endorctl_arch)"
  install_dir="$(_endorctl_install_dir)"
  mkdir -p "$install_dir"

  if [[ "$os" == "windows" ]]; then
    bin_name="endorctl.exe"
  else
    bin_name="endorctl"
  fi

  version="$ENDOR_PLUGIN_ENDORCTL_VERSION"
  checksum="$ENDOR_PLUGIN_ENDORCTL_CHECKSUM"

  if [[ -z "$version" ]]; then
    log_group ":endorlabs: Resolving latest endorctl version from $api/meta/version"
    local version_json
    if ! version_json="$(curl -fsSL "$api/meta/version")"; then
      log_fatal "endorlabs plugin: failed to fetch $api/meta/version"
    fi
    version="$(_json_get "$version_json" ClientVersion)"
    if [[ -z "$version" || "$version" == "null" ]]; then
      version="$(_json_get "$version_json" Service Version)"
    fi
    if [[ -z "$version" || "$version" == "null" ]]; then
      log_fatal "endorlabs plugin: could not parse ClientVersion from $api/meta/version"
    fi
    if [[ -z "$checksum" ]]; then
      checksum="$(_json_get_checksum "$version_json" "$os" "$arch")"
    fi
  fi

  if [[ -z "$checksum" ]]; then
    log_fatal "endorlabs plugin: no checksum available for endorctl ${version} (${os}/${arch})"
  fi

  url="${api}/download/endorlabs/${version}/binaries/endorctl_${version}_${os}_${arch}"
  if [[ "$os" == "windows" ]]; then
    url="${url}.exe"
  fi
  tmp_file="${install_dir}/${bin_name}.download"

  log_group ":endorlabs: Downloading endorctl ${version} (${os}/${arch})"
  if ! curl -fsSL -o "$tmp_file" "$url"; then
    log_fatal "endorlabs plugin: failed to download $url"
  fi

  local actual
  actual="$(_sha256 "$tmp_file")"
  if [[ "$actual" != "$checksum" ]]; then
    rm -f "$tmp_file"
    log_fatal "endorlabs plugin: checksum mismatch for endorctl ${version} (expected $checksum, got $actual)"
  fi

  mv "$tmp_file" "${install_dir}/${bin_name}"
  chmod +x "${install_dir}/${bin_name}" || true
  export PATH="${install_dir}:${PATH}"
  log_group ":endorlabs: endorctl ${version} installed to ${install_dir}"
}

# Minimal JSON value extractor: prefers jq when available, falls back to
# a regex pass that handles the (flat) /meta/version shape we care about.
# Usage: _json_get "$json" key            # top-level string
#        _json_get "$json" parent child   # nested string (depth 2)
function _json_get() {
  local json="$1"
  shift
  if command -v jq >/dev/null 2>&1; then
    local filter=""
    for key in "$@"; do
      filter="${filter}.${key}"
    done
    echo "$json" | jq -r "$filter" 2>/dev/null
    return 0
  fi
  # Fallback: tolerate either flat or nested-by-one-level shapes.
  local last="$1"
  if [[ "$#" -ge 2 ]]; then
    last="$2"
  fi
  echo "$json" | tr -d '\n' \
    | grep -oE "\"${last}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -n1 \
    | sed -E "s/.*\"${last}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
}

# Pick the platform-specific checksum out of the version response.
# Field names mirror the @actions/http-client response (ClientChecksums).
function _json_get_checksum() {
  local json="$1" os="$2" arch="$3" key=""
  case "${os}_${arch}" in
    linux_amd64)   key="ARCH_TYPE_LINUX_AMD64" ;;
    linux_arm64)   key="ARCH_TYPE_LINUX_ARM64" ;;
    macos_amd64)   key="ARCH_TYPE_MACOS_AMD64" ;;
    macos_arm64)   key="ARCH_TYPE_MACOS_ARM64" ;;
    windows_amd64) key="ARCH_TYPE_WINDOWS_AMD64" ;;
    *)             return 0 ;;
  esac
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r ".ClientChecksums.${key} // empty" 2>/dev/null
  else
    echo "$json" | tr -d '\n' \
      | grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -n1 \
      | sed -E "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
  fi
}

function _append_global_auth_args() {
  # shellcheck disable=SC2178 # nameref to caller array
  local -n args_ref="$1"

  if [[ -n "$ENDOR_PLUGIN_API" ]]; then
    args_ref+=("--api=${ENDOR_PLUGIN_API}")
  fi
  if [[ -n "$ENDOR_PLUGIN_AWS_ROLE_ARN" ]]; then
    args_ref+=("--aws-role-arn=${ENDOR_PLUGIN_AWS_ROLE_ARN}")
  fi
  if [[ "$ENDOR_PLUGIN_ENABLE_AZURE_MANAGED_IDENTITY" == "true" ]]; then
    args_ref+=("--enable-azure-managed-identity")
  fi
  if [[ -n "$ENDOR_PLUGIN_GCP_SERVICE_ACCOUNT" ]]; then
    args_ref+=("--gcp-service-account=${ENDOR_PLUGIN_GCP_SERVICE_ACCOUNT}")
  fi
}

function _append_common_logging_output_args() {
  # shellcheck disable=SC2178 # nameref to caller array
  local -n args_ref="$1"
  args_ref+=("--output-type=${ENDOR_PLUGIN_OUTPUT_TYPE}")
  args_ref+=("--log-level=${ENDOR_PLUGIN_LOG_LEVEL}")
  args_ref+=("--verbose=${ENDOR_PLUGIN_LOG_VERBOSE}")
}

function _append_additional_args() {
  # shellcheck disable=SC2178 # nameref to caller array
  local -n args_ref="$1"
  if [[ -n "$ENDOR_PLUGIN_ADDITIONAL_ARGS" ]]; then
    # shellcheck disable=SC2206
    local -a extra=($ENDOR_PLUGIN_ADDITIONAL_ARGS)
    args_ref+=("${extra[@]}")
  fi
}

function _ensure_output_parent_dir() {
  local path="$1"
  [[ -n "$path" ]] || return 0
  local dir
  dir="$(dirname "$path")"
  [[ -n "$dir" && "$dir" != "." ]] && mkdir -p "$dir"
}

function _run_endorctl_with_capture() {
  local -a args=("$@")
  ENDOR_PLUGIN_CAPTURE_FILE=""
  if [[ -n "$ENDOR_PLUGIN_OUTPUT_FILE" ]]; then
    _ensure_output_parent_dir "$ENDOR_PLUGIN_OUTPUT_FILE"
    if [[ "$ENDOR_PLUGIN_ANNOTATE" == "true" ]]; then
      ENDOR_PLUGIN_CAPTURE_FILE="$(mktemp)"
      endorctl "${args[@]}" | tee "$ENDOR_PLUGIN_OUTPUT_FILE" "$ENDOR_PLUGIN_CAPTURE_FILE"
    else
      endorctl "${args[@]}" | tee "$ENDOR_PLUGIN_OUTPUT_FILE"
    fi
  else
    if [[ "$ENDOR_PLUGIN_ANNOTATE" == "true" ]]; then
      ENDOR_PLUGIN_CAPTURE_FILE="$(mktemp)"
      endorctl "${args[@]}" | tee "$ENDOR_PLUGIN_CAPTURE_FILE"
    else
      endorctl "${args[@]}"
    fi
  fi
}

# Build the full args array and exec `endorctl scan`.
function run_repo_scan() {
  local -a args=("scan" "--namespace=${ENDOR_PLUGIN_NAMESPACE}")
  _append_global_auth_args args
  _append_common_logging_output_args args

  if [[ "$ENDOR_PLUGIN_SCAN_DEPENDENCIES" == "true" ]]; then
    args+=("--dependencies=true")
  fi
  if [[ "$ENDOR_PLUGIN_SCAN_SECRETS" == "true" ]]; then
    args+=("--secrets=true")
  fi
  if [[ "$ENDOR_PLUGIN_SCAN_SAST" == "true" ]]; then
    args+=("--sast=true")
  fi
  if [[ "$ENDOR_PLUGIN_SCAN_TOOLS" == "true" ]]; then
    args+=("--tools=true")
  fi
  if [[ "$ENDOR_PLUGIN_SCAN_GITHUB_ACTIONS" == "true" ]]; then
    args+=("--ghactions=true")
  fi
  if [[ "$ENDOR_PLUGIN_SCAN_AI_MODELS" == "true" ]]; then
    args+=("--ai-models=true")
  fi
  if [[ "$ENDOR_PLUGIN_SCAN_GIT_LOGS" == "true" ]]; then
    args+=("--git-logs=true")
  fi
  if [[ "$ENDOR_PLUGIN_SCAN_PACKAGE" == "true" ]]; then
    args+=("--package=true")
    if [[ -n "$ENDOR_PLUGIN_PROJECT_NAME" ]]; then
      args+=("--project-name=${ENDOR_PLUGIN_PROJECT_NAME}")
    fi
  fi
  if [[ "$ENDOR_PLUGIN_PHANTOM_DEPENDENCIES" == "true" ]]; then
    args+=("--phantom-dependencies=true")
  fi
  if [[ "$ENDOR_PLUGIN_DISABLE_CODE_SNIPPET_STORAGE" == "true" ]]; then
    args+=("--disable-code-snippet-storage=true")
  fi
  if [[ "$ENDOR_PLUGIN_USE_BAZEL" == "true" ]]; then
    args+=("--use-bazel=true")
    if [[ -n "$ENDOR_PLUGIN_BAZEL_INCLUDE_TARGETS" ]]; then
      args+=("--bazel-include-targets=${ENDOR_PLUGIN_BAZEL_INCLUDE_TARGETS}")
    fi
    if [[ -n "$ENDOR_PLUGIN_BAZEL_EXCLUDE_TARGETS" ]]; then
      args+=("--bazel-exclude-targets=${ENDOR_PLUGIN_BAZEL_EXCLUDE_TARGETS}")
    fi
    # endorctl rejects --bazel-targets-query together with --bazel-include-targets.
    if [[ -n "$ENDOR_PLUGIN_BAZEL_TARGETS_QUERY" ]] && ! plugin_bazel_include_targets_configured; then
      args+=("--bazel-targets-query=${ENDOR_PLUGIN_BAZEL_TARGETS_QUERY}")
    fi
  fi

  if [[ -n "$ENDOR_PLUGIN_SCAN_PATH" ]]; then
    args+=("--path=${ENDOR_PLUGIN_SCAN_PATH}")
  fi

  # Map BUILDKITE_* env vars into endorctl --scan args (PR / baseline / comments).
  # pr: false disables PR mode even on PR-triggered builds. When pr is unset or
  # true, PR mode follows Buildkite (numeric BUILDKITE_PULL_REQUEST) or an
  # explicit pr_baseline (github-action also forces --pr when pr_baseline is set).
  local _branch="${BUILDKITE_BRANCH:-}"
  if [[ -n "$_branch" ]]; then
    args+=("--detached-ref-name=${_branch}")
  fi

  local pr_disabled=false
  if [[ "${ENDOR_PLUGIN_PR:-}" == "false" ]]; then
    pr_disabled=true
  fi

  local bk_pr="${BUILDKITE_PULL_REQUEST:-}"
  local has_numeric_pr=false
  if bk_pull_request_is_numeric; then
    has_numeric_pr=true
  fi

  local explicit_bl="${ENDOR_PLUGIN_PR_BASELINE:-}"
  local use_pr_flags=false
  if [[ "$pr_disabled" != true ]]; then
    if [[ "$has_numeric_pr" == true ]]; then
      use_pr_flags=true
    elif [[ -n "$explicit_bl" ]]; then
      use_pr_flags=true
    fi
  fi

  if [[ "$use_pr_flags" == true ]]; then
    args+=("--pr=true")
    if [[ "$has_numeric_pr" == true ]]; then
      args+=("--scm-pr-id=${bk_pr}")
    fi
    if [[ -n "$explicit_bl" ]]; then
      args+=("--pr-baseline=${explicit_bl}")
    elif [[ "${ENDOR_PLUGIN_ENABLE_PR_COMMENTS:-}" != "true" ]]; then
      if [[ -n "${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-}" ]]; then
        args+=("--pr-baseline=${BUILDKITE_PULL_REQUEST_BASE_BRANCH}")
      fi
    fi
  fi

  if [[ "${ENDOR_PLUGIN_PR_INCREMENTAL:-false}" == "true" ]]; then
    args+=("--pr-incremental=true")
  fi

  if [[ "${ENDOR_PLUGIN_ENABLE_PR_COMMENTS:-false}" == "true" ]]; then
    args+=("--enable-pr-comments=true")
    local scm_ev="${ENDOR_PLUGIN_SCM_TOKEN_ENV}"
    # Value must never be logged; validation ensures the env var is set.
    args+=("--scm-token=${!scm_ev}")
  fi

  if [[ -n "$ENDOR_PLUGIN_TAGS" ]]; then
    args+=("--tags=${ENDOR_PLUGIN_TAGS}")
  fi

  if [[ -n "$ENDOR_PLUGIN_SARIF_FILE" ]]; then
    _ensure_output_parent_dir "$ENDOR_PLUGIN_SARIF_FILE"
    args+=("--sarif-file=${ENDOR_PLUGIN_SARIF_FILE}")
  fi

  if [[ "$ENDOR_PLUGIN_EXIT_ON_POLICY_WARNING" == "true" ]]; then
    args+=("--exit-on-policy-warning")
  fi

  _append_additional_args args

  log_focus ":endorlabs: Running endorctl scan"
  _run_endorctl_with_capture "${args[@]}"
}

function run_container_scan() {
  local -a args=("container" "scan" "--namespace=${ENDOR_PLUGIN_NAMESPACE}")
  _append_global_auth_args args
  _append_common_logging_output_args args

  if [[ -n "$ENDOR_PLUGIN_IMAGE" ]]; then
    args+=("--image=${ENDOR_PLUGIN_IMAGE}")
  fi
  if [[ -n "$ENDOR_PLUGIN_IMAGE_TAR" ]]; then
    args+=("--image-tar=${ENDOR_PLUGIN_IMAGE_TAR}")
  fi
  if [[ "$ENDOR_PLUGIN_AS_REF" == "true" ]]; then
    args+=("--as-ref")
  fi
  if [[ "$ENDOR_PLUGIN_OS_REACHABILITY" == "true" ]]; then
    args+=("--os-reachability")
  fi
  if [[ -n "$ENDOR_PLUGIN_PROJECT_NAME" ]]; then
    args+=("--project-name=${ENDOR_PLUGIN_PROJECT_NAME}")
  fi
  if [[ -n "$ENDOR_PLUGIN_PROJECT_TAGS" ]]; then
    args+=("--project-tags=${ENDOR_PLUGIN_PROJECT_TAGS}")
  fi
  if [[ -n "$ENDOR_PLUGIN_CONTAINER_SCAN_PATH" ]]; then
    args+=("--path=${ENDOR_PLUGIN_CONTAINER_SCAN_PATH}")
  fi
  if [[ -n "$ENDOR_PLUGIN_PROFILING_DATA_DIR" ]]; then
    args+=("--profiling-data-dir=${ENDOR_PLUGIN_PROFILING_DATA_DIR}")
  fi

  _append_additional_args args

  log_focus ":endorlabs: Running endorctl container scan"
  _run_endorctl_with_capture "${args[@]}"
}

function run_artifact_sign() {
  local -a args=("artifact" "sign" "--namespace=${ENDOR_PLUGIN_NAMESPACE}")
  _append_global_auth_args args
  args+=("--log-level=${ENDOR_PLUGIN_LOG_LEVEL}")
  args+=("--verbose=${ENDOR_PLUGIN_LOG_VERBOSE}")
  args+=("--name=${ENDOR_PLUGIN_ARTIFACT_NAME}")
  args+=("--source-repository-ref=${ENDOR_PLUGIN_SOURCE_REPOSITORY_REF}")
  args+=("--certificate-oidc-issuer=${ENDOR_PLUGIN_CERTIFICATE_OIDC_ISSUER}")

  if [[ -n "$ENDOR_PLUGIN_CERTIFICATE_IDENTITY" ]]; then
    args+=("--certificate-identity=${ENDOR_PLUGIN_CERTIFICATE_IDENTITY}")
  fi
  if [[ -n "$ENDOR_PLUGIN_SOURCE_REPOSITORY" ]]; then
    args+=("--source-repository=${ENDOR_PLUGIN_SOURCE_REPOSITORY}")
  fi
  if [[ -n "$ENDOR_PLUGIN_SOURCE_REPOSITORY_OWNER" ]]; then
    args+=("--source-repository-owner=${ENDOR_PLUGIN_SOURCE_REPOSITORY_OWNER}")
  fi
  if [[ -n "$ENDOR_PLUGIN_SOURCE_REPOSITORY_DIGEST" ]]; then
    args+=("--source-repository-digest=${ENDOR_PLUGIN_SOURCE_REPOSITORY_DIGEST}")
  fi
  if [[ -n "$ENDOR_PLUGIN_BUILD_CONFIG_NAME" ]]; then
    args+=("--build-config-name=${ENDOR_PLUGIN_BUILD_CONFIG_NAME}")
  fi
  if [[ -n "$ENDOR_PLUGIN_BUILD_CONFIG_DIGEST" ]]; then
    args+=("--build-config-digest=${ENDOR_PLUGIN_BUILD_CONFIG_DIGEST}")
  fi
  if [[ -n "$ENDOR_PLUGIN_RUNNER_ENVIRONMENT" ]]; then
    args+=("--runner-environment=${ENDOR_PLUGIN_RUNNER_ENVIRONMENT}")
  fi

  _append_additional_args args

  log_focus ":endorlabs: Running endorctl artifact sign"
  _run_endorctl_with_capture "${args[@]}"
}

function run_artifact_verify() {
  local -a args=("artifact" "verify" "--namespace=${ENDOR_PLUGIN_NAMESPACE}")
  _append_global_auth_args args
  args+=("--log-level=${ENDOR_PLUGIN_LOG_LEVEL}")
  args+=("--verbose=${ENDOR_PLUGIN_LOG_VERBOSE}")
  args+=("--name=${ENDOR_PLUGIN_ARTIFACT_NAME}")
  args+=("--certificate-oidc-issuer=${ENDOR_PLUGIN_CERTIFICATE_OIDC_ISSUER}")
  _append_additional_args args

  log_focus ":endorlabs: Running endorctl artifact verify"
  _run_endorctl_with_capture "${args[@]}"
}

function run_endorctl_mode() {
  case "${ENDOR_PLUGIN_MODE:-scan}" in
    scan)
      if [[ "${ENDOR_PLUGIN_SCAN_CONTAINER:-false}" == "true" ]]; then
        run_container_scan
      else
        run_repo_scan
      fi
      ;;
    sign)
      run_artifact_sign
      ;;
    verify)
      run_artifact_verify
      ;;
    *)
      log_fatal "endorlabs plugin: unsupported mode '${ENDOR_PLUGIN_MODE}' (expected scan, sign, or verify)"
      ;;
  esac
}

function resolve_effective_exit_code() {
  local raw_exit="${1:-0}"
  local effective_exit="$raw_exit"

  if [[ "$raw_exit" -eq 128 && "${ENDOR_PLUGIN_FAIL_ON_POLICY:-true}" != "true" ]]; then
    log_warn "endorlabs plugin: converting policy failure exit 128 to success (fail_on_policy=false)"
    effective_exit=0
  fi
  if [[ "$effective_exit" -ne 0 && "${ENDOR_PLUGIN_SOFT_FAIL:-false}" == "true" ]]; then
    if [[ "$raw_exit" -eq 128 && "${ENDOR_PLUGIN_FAIL_ON_POLICY:-true}" == "true" ]]; then
      : # policy block (exit 128): soft_fail does not override fail_on_policy
    else
      log_warn "endorlabs plugin: soft_fail=true, continuing despite endorctl exit ${raw_exit}"
      effective_exit=0
    fi
  fi

  echo "$effective_exit"
}

function upload_artifacts_if_configured() {
  if [[ "${ENDOR_PLUGIN_UPLOAD_ARTIFACTS:-false}" != "true" ]]; then
    return 0
  fi
  if ! command -v buildkite-agent >/dev/null 2>&1; then
    log_warn "endorlabs plugin: upload_artifacts=true but buildkite-agent is not available; skipping upload"
    return 0
  fi

  local -a paths=()
  if [[ -n "${ENDOR_PLUGIN_ARTIFACT_PATHS:-}" ]]; then
    # shellcheck disable=SC2206
    paths=(${ENDOR_PLUGIN_ARTIFACT_PATHS})
  else
    if [[ -n "${ENDOR_PLUGIN_OUTPUT_FILE:-}" ]]; then
      paths+=("${ENDOR_PLUGIN_OUTPUT_FILE}")
    fi
    if [[ -n "${ENDOR_PLUGIN_SARIF_FILE:-}" ]]; then
      paths+=("${ENDOR_PLUGIN_SARIF_FILE}")
    fi
  fi

  local path
  for path in "${paths[@]}"; do
    if [[ -f "$path" ]]; then
      log_focus ":endorlabs: Uploading artifact ${path}"
      buildkite-agent artifact upload "$path"
    else
      log_warn "endorlabs plugin: artifact path not found, skipping upload: $path"
    fi
  done
}

function _escape_html() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&#39;}"
  echo "$value"
}

function _read_scan_finding_count() {
  local source_file="$1"
  [[ -n "$source_file" && -f "$source_file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  jq -r '
    .summary.findings.total // .findings.total // .summary.total // .total
    // (if (.all_findings | type == "array") then (.all_findings | length) else empty end)
    // (if (.runs | type == "array") then ((.runs | map(.results | length)) | add) else empty end)
    // empty
  ' "$source_file" 2>/dev/null | awk 'NF { print; exit }'
}

function _level_display_name() {
  local raw="$1"
  raw="${raw#FINDING_LEVEL_}"
  raw="${raw//_/ }"
  if [[ -z "$raw" ]]; then
    echo "Unknown"
    return 0
  fi
  local first="${raw:0:1}"
  local rest="${raw:1}"
  rest="${rest,,}"
  echo "${first^^}${rest}"
}

function _build_findings_annotation_html() {
  local source_file="$1"
  local limit="$2"
  [[ -n "$source_file" && -f "$source_file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local has_findings
  has_findings="$(jq -r 'if (.all_findings | type) == "array" and (.all_findings | length) > 0 then "yes" else empty end' \
    "$source_file" 2>/dev/null || true)"
  [[ "$has_findings" == "yes" ]] || return 0

  local severity_html=""
  while IFS=$'\t' read -r level count; do
    [[ -n "$level" && -n "$count" ]] || continue
    severity_html="${severity_html}<li>$(_escape_html "$(_level_display_name "$level")"): $(_escape_html "$count")</li>"
  done < <(jq -r '
    [.all_findings[]? | .spec.level // "FINDING_LEVEL_UNKNOWN"]
    | group_by(.)
    | map("\(.[0])\t\(length)")
    | .[]
  ' "$source_file" 2>/dev/null)

  if [[ -n "$severity_html" ]]; then
    echo "<p><strong>By severity</strong></p><ul>${severity_html}</ul>"
  fi

  if [[ -z "$limit" || "$limit" -le 0 ]]; then
    return 0
  fi

  local table_rows=""
  local level reach title detail url loc_cell
  while IFS=$'\t' read -r level reach title detail url; do
    [[ -n "$level" ]] || continue
    if [[ -n "$url" && "$url" =~ ^https?:// ]]; then
      loc_cell="<a href=\"$(_escape_html "$url")\">$(_escape_html "$detail")</a>"
    else
      loc_cell="$(_escape_html "$detail")"
    fi
    table_rows="${table_rows}<tr>"
    table_rows="${table_rows}<td>$(_escape_html "$reach")</td>"
    table_rows="${table_rows}<td>$(_escape_html "$(_level_display_name "$level")")</td>"
    table_rows="${table_rows}<td>$(_escape_html "$title")</td>"
    table_rows="${table_rows}<td>${loc_cell}</td>"
    table_rows="${table_rows}</tr>"
  done < <(jq -r --argjson limit "$limit" '
    def rank($l):
      if ($l | test("CRITICAL")) then 0
      elif ($l | test("HIGH")) then 1
      elif ($l | test("MEDIUM")) then 2
      elif ($l | test("LOW")) then 3
      else 4 end;
    def reachability:
      (.spec.finding_tags // []) as $tags |
      if any($tags[]?; . == "FINDING_TAGS_REACHABLE_DEPENDENCY" or . == "FINDING_TAGS_REACHABLE_FUNCTION") then "Reachable"
      elif any($tags[]?; . == "FINDING_TAGS_POTENTIALLY_REACHABLE_DEPENDENCY" or . == "FINDING_TAGS_POTENTIALLY_REACHABLE_FUNCTION") then "Potentially reachable"
      else "Not reachable"
      end;
    def finding_url:
      (.spec.finding_metadata.custom.location // "") as $custom |
      if (($custom | length) > 0) and ($custom | startswith("http")) then $custom
      else (.spec.location_urls // {} | to_entries | .[0].value // empty)
      end;
    def finding_detail:
      (.spec.finding_metadata.custom.location // "") as $loc |
      if ($loc | startswith("http")) then
        ($loc | split("/") | last | gsub("#L"; ":"))
      else
        (.spec.dependency_file_paths[0]
         // .spec.target_dependency_name
         // ((.spec.location_urls // {}) | keys[0])
         // "—")
      end;
    [.all_findings[]?
      | {
          level: (.spec.level // "FINDING_LEVEL_UNKNOWN"),
          reach: reachability,
          title: (
            (.meta.description // .meta.name // "Finding")
            | gsub("\\s+"; " ")
            | if length > 100 then .[0:97] + "…" else . end
          ),
          detail: finding_detail,
          url: finding_url
        }
    ]
    | sort_by(rank(.level))
    | .[0:$limit][]
    | [.level, .reach, .title, .detail, .url]
    | @tsv
  ' "$source_file" 2>/dev/null)

  if [[ -z "$table_rows" ]]; then
    return 0
  fi

  local total
  total="$(jq -r '(.all_findings | length) // 0' "$source_file" 2>/dev/null)"
  if [[ -n "$total" && "$total" -gt "$limit" ]]; then
    echo "<p><strong>Top ${limit} of ${total} findings</strong> (full list in JSON artifact)</p>"
  else
    echo "<p><strong>Findings</strong></p>"
  fi
  echo "<table><thead><tr><th>Reach</th><th>Severity</th><th>Finding</th><th>Location</th></tr></thead><tbody>${table_rows}</tbody></table>"
}

function _annotate_artifact_link_html() {
  local path="${ENDOR_PLUGIN_OUTPUT_FILE:-}"
  [[ -n "$path" && -f "$path" ]] || return 0
  local escaped_path
  escaped_path="$(_escape_html "$path")"
  echo "<p><a href=\"artifact://${escaped_path}\">Download full scan JSON</a></p>"
}

function annotate_scan() {
  if [[ "$ENDOR_PLUGIN_ANNOTATE" != "true" ]]; then
    return 0
  fi

  if ! command -v buildkite-agent >/dev/null 2>&1; then
    log_warn "endorlabs plugin: annotate=true but buildkite-agent is not available; skipping annotation"
    return 0
  fi

  local scan_exit="${1:-0}"

  local style="success"
  local message="Scan completed successfully."
  case "$scan_exit" in
    0)
      style="success"
      message="Scan completed successfully."
      ;;
    129)
      style="warning"
      message="Scan completed with policy warnings (exit-on-policy-warning)."
      ;;
    128)
      style="error"
      message="Blocking admission policy failed."
      ;;
    33)
      style="error"
      message="Scan failed due to a license error."
      ;;
    4)
      style="error"
      message="Scan failed due to conflicting authentication methods."
      ;;
    *)
      style="error"
      message="Scan failed (exit code ${scan_exit})."
      ;;
  esac

  local findings_count=""
  if [[ -n "${ENDOR_PLUGIN_CAPTURE_FILE:-}" && -f "${ENDOR_PLUGIN_CAPTURE_FILE}" ]]; then
    findings_count="$(_read_scan_finding_count "$ENDOR_PLUGIN_CAPTURE_FILE")"
  elif [[ -n "${ENDOR_PLUGIN_OUTPUT_FILE:-}" ]]; then
    findings_count="$(_read_scan_finding_count "$ENDOR_PLUGIN_OUTPUT_FILE")"
  fi

  local escaped_message
  escaped_message="$(_escape_html "$message")"
  local details_html=""
  if [[ -n "$findings_count" ]]; then
    details_html="<p><strong>Findings:</strong> $(_escape_html "$findings_count")</p>"
  fi

  local mode_label="scan"
  local annotate_context="${ENDOR_PLUGIN_ANNOTATE_CONTEXT:-}"
  if [[ -z "$annotate_context" ]]; then
    annotate_context="endorlabs-scan"
    if [[ "${ENDOR_PLUGIN_MODE:-scan}" == "sign" ]]; then
      mode_label="artifact sign"
      annotate_context="endorlabs-sign"
    elif [[ "${ENDOR_PLUGIN_MODE:-scan}" == "verify" ]]; then
      mode_label="artifact verify"
      annotate_context="endorlabs-verify"
    elif [[ "${ENDOR_PLUGIN_SCAN_CONTAINER:-false}" == "true" ]]; then
      mode_label="container scan"
      annotate_context="endorlabs-container"
    fi
  elif [[ "${ENDOR_PLUGIN_MODE:-scan}" == "sign" ]]; then
    mode_label="artifact sign"
  elif [[ "${ENDOR_PLUGIN_MODE:-scan}" == "verify" ]]; then
    mode_label="artifact verify"
  elif [[ "${ENDOR_PLUGIN_SCAN_CONTAINER:-false}" == "true" ]]; then
    mode_label="container scan"
  fi

  if [[ -n "${ENDOR_PLUGIN_TAGS:-}" ]]; then
    details_html="${details_html}<p><strong>Tags:</strong> $(_escape_html "$ENDOR_PLUGIN_TAGS")</p>"
  fi

  local findings_source=""
  if [[ -n "${ENDOR_PLUGIN_CAPTURE_FILE:-}" && -f "${ENDOR_PLUGIN_CAPTURE_FILE}" ]]; then
    findings_source="${ENDOR_PLUGIN_CAPTURE_FILE}"
  elif [[ -n "${ENDOR_PLUGIN_OUTPUT_FILE:-}" && -f "${ENDOR_PLUGIN_OUTPUT_FILE}" ]]; then
    findings_source="${ENDOR_PLUGIN_OUTPUT_FILE}"
  fi

  local findings_html=""
  if [[ -n "$findings_source" ]]; then
    findings_html="$(_build_findings_annotation_html "$findings_source" "${ENDOR_PLUGIN_ANNOTATE_FINDINGS_LIMIT:-15}")"
    if [[ -n "$findings_html" ]]; then
      details_html="${details_html}${findings_html}"
    fi
    local artifact_link
    artifact_link="$(_annotate_artifact_link_html)"
    if [[ -n "$artifact_link" ]]; then
      details_html="${details_html}${artifact_link}"
    fi
  fi

  local annotation="<h3>Endor Labs ${mode_label}</h3><p>${escaped_message}</p>${details_html}"
  local -a annotate_args=(annotate "$annotation" --style "$style" --context "$annotate_context")
  if [[ "${ENDOR_PLUGIN_ANNOTATE_SCOPE:-build}" == "job" ]]; then
    annotate_args+=(--scope job)
  fi

  log_focus ":endorlabs: Publishing Buildkite annotation (context=${annotate_context}, scope=${ENDOR_PLUGIN_ANNOTATE_SCOPE:-build})"
  if ! buildkite-agent "${annotate_args[@]}"; then
    log_warn "endorlabs plugin: buildkite-agent annotate failed (missing agent token or not in a Buildkite job?); continuing"
  fi

  if [[ -n "${ENDOR_PLUGIN_CAPTURE_FILE:-}" && -f "${ENDOR_PLUGIN_CAPTURE_FILE}" ]]; then
    rm -f "${ENDOR_PLUGIN_CAPTURE_FILE}"
  fi
}
