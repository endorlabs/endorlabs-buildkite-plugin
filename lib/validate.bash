#!/bin/bash

# Validation helpers for scan-mode option combinations.

function _is_true() {
  [[ "${1:-false}" == "true" ]]
}

# Validate scan option combinations to mirror github-action scan.ts behavior.
function validate_scan_config() {
  local mode="${ENDOR_PLUGIN_MODE:-scan}"
  local scan_dependencies="${ENDOR_PLUGIN_SCAN_DEPENDENCIES:-false}"
  local scan_secrets="${ENDOR_PLUGIN_SCAN_SECRETS:-false}"
  local scan_sast="${ENDOR_PLUGIN_SCAN_SAST:-false}"
  local scan_tools="${ENDOR_PLUGIN_SCAN_TOOLS:-false}"
  local scan_package="${ENDOR_PLUGIN_SCAN_PACKAGE:-false}"
  local scan_github_actions="${ENDOR_PLUGIN_SCAN_GITHUB_ACTIONS:-false}"
  local scan_ai_models="${ENDOR_PLUGIN_SCAN_AI_MODELS:-false}"
  local scan_git_logs="${ENDOR_PLUGIN_SCAN_GIT_LOGS:-false}"
  local disable_code_snippet_storage="${ENDOR_PLUGIN_DISABLE_CODE_SNIPPET_STORAGE:-false}"
  local scan_container="${ENDOR_PLUGIN_SCAN_CONTAINER:-false}"
  local api_key_env="${ENDOR_PLUGIN_API_KEY_ENV:-}"
  local api_secret_env="${ENDOR_PLUGIN_API_SECRET_ENV:-}"
  local aws_role_arn="${ENDOR_PLUGIN_AWS_ROLE_ARN:-}"
  local enable_azure_managed_identity="${ENDOR_PLUGIN_ENABLE_AZURE_MANAGED_IDENTITY:-false}"
  local gcp_service_account="${ENDOR_PLUGIN_GCP_SERVICE_ACCOUNT:-}"

  if [[ "$mode" != "scan" && "$mode" != "sign" && "$mode" != "verify" ]]; then
    log_fatal "endorlabs plugin: mode must be one of scan, sign, or verify"
  fi

  if [[ "$mode" == "sign" || "$mode" == "verify" ]]; then
    if _is_true "$scan_dependencies" || _is_true "$scan_secrets" || _is_true "$scan_sast" || _is_true "$scan_tools" || _is_true "$scan_package" || _is_true "$scan_github_actions" || _is_true "$scan_container"; then
      log_fatal "endorlabs plugin: scan_* options are only valid in mode=scan"
    fi
    if [[ -z "${ENDOR_PLUGIN_ARTIFACT_NAME:-}" ]]; then
      log_fatal "endorlabs plugin: artifact_name is required when mode=${mode}"
    fi
    if [[ -z "${ENDOR_PLUGIN_CERTIFICATE_OIDC_ISSUER:-}" ]]; then
      log_fatal "endorlabs plugin: certificate_oidc_issuer is required when mode=${mode}"
    fi
    if [[ "$mode" == "sign" && -z "${ENDOR_PLUGIN_SOURCE_REPOSITORY_REF:-}" ]]; then
      log_fatal "endorlabs plugin: source_repository_ref is required when mode=sign"
    fi
  fi

  if [[ "$mode" != "scan" ]]; then
    # Remaining validations in this function are scan-mode specific.
    scan_dependencies="false"
    scan_secrets="false"
    scan_sast="false"
    scan_tools="false"
    scan_package="false"
    scan_github_actions="false"
    scan_ai_models="false"
    scan_git_logs="false"
    disable_code_snippet_storage="false"
    scan_container="false"
  fi

  if [[ "$mode" == "scan" ]] && ! _is_true "$scan_dependencies" \
    && ! _is_true "$scan_secrets" \
    && ! _is_true "$scan_sast" \
    && ! _is_true "$scan_tools" \
    && ! _is_true "$scan_package" \
    && ! _is_true "$scan_github_actions" \
    && ! _is_true "$scan_container"; then
    log_fatal "endorlabs plugin: at least one scan kind must be enabled (scan_dependencies, scan_secrets, scan_sast, scan_tools, scan_github_actions, scan_package, or scan_container)"
  fi

  if _is_true "$scan_container"; then
    if _is_true "$scan_dependencies" || _is_true "$scan_secrets" || _is_true "$scan_sast" || _is_true "$scan_tools" || _is_true "$scan_github_actions" || _is_true "$scan_package" || _is_true "$scan_ai_models" || _is_true "$scan_git_logs"; then
      log_fatal "endorlabs plugin: scan_container cannot be combined with repository/package scan kinds; use a separate step"
    fi
    if [[ -z "${ENDOR_PLUGIN_IMAGE:-}" && -z "${ENDOR_PLUGIN_IMAGE_TAR:-}" ]]; then
      log_fatal "endorlabs plugin: scan_container=true requires image or image_tar"
    fi
    if [[ -n "${ENDOR_PLUGIN_IMAGE:-}" && -n "${ENDOR_PLUGIN_IMAGE_TAR:-}" ]]; then
      log_fatal "endorlabs plugin: image and image_tar are mutually exclusive; provide only one"
    fi
  fi

  if _is_true "$scan_package"; then
    if _is_true "$scan_container"; then
      log_fatal "endorlabs plugin: scan_package and scan_container cannot be enabled together"
    fi
    if _is_true "$scan_dependencies"; then
      log_fatal "endorlabs plugin: scan_package and scan_dependencies cannot be enabled together"
    fi
    if _is_true "$scan_secrets"; then
      log_fatal "endorlabs plugin: scan_package and scan_secrets cannot be enabled together"
    fi
    if _is_true "$scan_sast"; then
      log_fatal "endorlabs plugin: scan_package and scan_sast cannot be enabled together"
    fi
    if _is_true "$scan_ai_models"; then
      log_fatal "endorlabs plugin: scan_package and scan_ai_models cannot be enabled together"
    fi
    if [[ -z "${ENDOR_PLUGIN_PROJECT_NAME:-}" ]]; then
      log_fatal "endorlabs plugin: project_name is required when scan_package=true"
    fi
    if [[ -z "${ENDOR_PLUGIN_SCAN_PATH:-}" ]]; then
      log_fatal "endorlabs plugin: scan_path is required when scan_package=true"
    fi
  fi

  if _is_true "$scan_ai_models" && ! _is_true "$scan_dependencies"; then
    log_fatal "endorlabs plugin: scan_ai_models requires scan_dependencies=true"
  fi

  if _is_true "$scan_git_logs" && ! _is_true "$scan_secrets"; then
    log_fatal "endorlabs plugin: scan_git_logs requires scan_secrets=true"
  fi

  if _is_true "$disable_code_snippet_storage" && ! _is_true "$scan_sast"; then
    log_fatal "endorlabs plugin: disable_code_snippet_storage requires scan_sast=true"
  fi

  local bazel_include="${ENDOR_PLUGIN_BAZEL_INCLUDE_TARGETS:-}"
  local bazel_query="${ENDOR_PLUGIN_BAZEL_TARGETS_QUERY:-}"
  if [[ -n "$bazel_include" && -n "$bazel_query" ]]; then
    log_fatal "endorlabs plugin: bazel_include_targets and bazel_targets_query are mutually exclusive; use only one"
  fi

  # Cloud keyless auth modes are mutually exclusive and cannot be mixed with
  # API key mode.
  local auth_modes=0
  local has_api_mode=false
  if [[ -n "$api_key_env" || -n "$api_secret_env" || -n "${ENDOR_API_CREDENTIALS_KEY:-}" || -n "${ENDOR_API_CREDENTIALS_SECRET:-}" ]]; then
    has_api_mode=true
    auth_modes=$((auth_modes + 1))
  fi
  if [[ -n "$aws_role_arn" ]]; then
    auth_modes=$((auth_modes + 1))
  fi
  if _is_true "$enable_azure_managed_identity"; then
    auth_modes=$((auth_modes + 1))
  fi
  if [[ -n "$gcp_service_account" ]]; then
    auth_modes=$((auth_modes + 1))
  fi

  if [[ "$auth_modes" -gt 1 ]]; then
    log_fatal "endorlabs plugin: provide exactly one auth mode: api_key_env+api_secret_env (or ENDOR_API_CREDENTIALS_*), aws_role_arn, enable_azure_managed_identity, or gcp_service_account"
  fi

  if [[ "$has_api_mode" == true ]]; then
    local resolved_key=""
    local resolved_secret=""
    if [[ -n "$api_key_env" ]]; then
      resolved_key="${!api_key_env:-}"
    fi
    if [[ -n "$api_secret_env" ]]; then
      resolved_secret="${!api_secret_env:-}"
    fi
    : "${resolved_key:=${ENDOR_API_CREDENTIALS_KEY:-}}"
    : "${resolved_secret:=${ENDOR_API_CREDENTIALS_SECRET:-}}"
    if [[ -z "$resolved_key" || -z "$resolved_secret" ]]; then
      log_fatal "endorlabs plugin: api key auth requires both key and secret (set api_key_env+api_secret_env or pre-export ENDOR_API_CREDENTIALS_KEY and ENDOR_API_CREDENTIALS_SECRET)"
    fi
  fi

  # PR incremental + PR comments (mirrors github-action scan.ts checks;
  # Buildkite uses numeric BUILDKITE_PULL_REQUEST and scm_token_env indirection.)
  local pr_incremental="${ENDOR_PLUGIN_PR_INCREMENTAL:-false}"
  local enable_pr_comments="${ENDOR_PLUGIN_ENABLE_PR_COMMENTS:-false}"
  local plugin_pr="${ENDOR_PLUGIN_PR:-}"
  local explicit_pr_baseline="${ENDOR_PLUGIN_PR_BASELINE:-}"

  if _is_true "$pr_incremental"; then
    if [[ "$plugin_pr" == "false" ]]; then
      log_fatal "endorlabs plugin: pr_incremental cannot be used together with pr: false"
    fi
    local has_bk_pr=false
    if bk_pull_request_is_numeric; then
      has_bk_pr=true
    fi
    local has_explicit_bl=false
    if [[ -n "$explicit_pr_baseline" ]]; then
      has_explicit_bl=true
    fi
    if [[ "$has_bk_pr" != true && "$has_explicit_bl" != true ]]; then
      log_fatal "endorlabs plugin: pr_incremental requires a numeric BUILDKITE_PULL_REQUEST or pr_baseline to be set"
    fi
    if ! _is_true "$enable_pr_comments"; then
      if [[ "$has_explicit_bl" != true && -z "${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-}" ]]; then
        log_fatal "endorlabs plugin: pr_incremental requires pr_baseline, BUILDKITE_PULL_REQUEST_BASE_BRANCH, or enable_pr_comments=true"
      fi
    fi
  fi

  if _is_true "$enable_pr_comments"; then
    if [[ "$plugin_pr" == "false" ]]; then
      log_fatal "endorlabs plugin: enable_pr_comments cannot be used with pr: false on pull-request builds; unset pr or set pr: true"
    fi
    if ! bk_pull_request_is_numeric; then
      log_fatal "endorlabs plugin: enable_pr_comments requires a pull-request build (numeric BUILDKITE_PULL_REQUEST)"
    fi
    if [[ -z "${ENDOR_PLUGIN_SCM_TOKEN_ENV:-}" ]]; then
      log_fatal "endorlabs plugin: enable_pr_comments requires scm_token_env (env var name whose value is passed to endorctl as --scm-token)"
    fi
    local scm_ref="${ENDOR_PLUGIN_SCM_TOKEN_ENV}"
    if [[ -z "${!scm_ref:-}" ]]; then
      log_fatal "endorlabs plugin: enable_pr_comments requires env var '${ENDOR_PLUGIN_SCM_TOKEN_ENV}' (from scm_token_env) to be set and non-empty"
    fi
  fi
}
