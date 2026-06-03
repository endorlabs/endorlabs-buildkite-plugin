#!/bin/bash

# Shared helpers for the Endor Labs Buildkite plugin.
#
# Patterns mirror buildkite-plugins/docker-compose-buildkite-plugin:
# - plugin_read_config: read BUILDKITE_PLUGIN_<ID>_<KEY> with optional default
# - plugin_read_list / prefix_read_list: handle YAML array → KEY_0, KEY_1, ...
# - log_group / log_subgroup: Buildkite collapsible group markers (--- / +++)

PLUGIN_ENV_PREFIX=""

# Resolve BUILDKITE_PLUGIN_* prefix from the agent (endorlabs vs endorlabs-buildkite-plugin path).
function plugin_env_prefix() {
  if [[ -n "$PLUGIN_ENV_PREFIX" ]]; then
    echo "$PLUGIN_ENV_PREFIX"
    return 0
  fi
  local name
  while IFS= read -r name; do
    if [[ "$name" =~ ^BUILDKITE_PLUGIN_(.+)_NAMESPACE$ ]]; then
      PLUGIN_ENV_PREFIX="BUILDKITE_PLUGIN_${BASH_REMATCH[1]}"
      echo "$PLUGIN_ENV_PREFIX"
      return 0
    fi
  done < <(compgen -e | grep '^BUILDKITE_PLUGIN_.*_NAMESPACE$' || true)
  PLUGIN_ENV_PREFIX="BUILDKITE_PLUGIN_ENDORLABS"
  echo "$PLUGIN_ENV_PREFIX"
}

# Read a single plugin config value by KEY (uppercase, underscored).
# Usage: plugin_read_config NAMESPACE
#        plugin_read_config SCAN_PATH "."
function plugin_read_config() {
  local prefix
  prefix="$(plugin_env_prefix)"
  local var="${prefix}_${1}"
  local default="${2:-}"
  echo "${!var:-$default}"
}

# Return success if a plugin config key is set (even to empty string).
function plugin_config_exists() {
  local prefix
  prefix="$(plugin_env_prefix)"
  local var="${prefix}_${1}"
  [ "${!var+is_set}" != "" ]
}

# Read a list from a given env-var prefix; supports both scalar and
# numbered (PREFIX_0, PREFIX_1, ...) forms produced by Buildkite for YAML arrays.
function prefix_read_list() {
  local prefix="$1"
  local parameter="${prefix}_0"

  if [[ -n "${!parameter:-}" ]]; then
    local i=0
    local parameter="${prefix}_${i}"
    while [[ -n "${!parameter:-}" ]]; do
      echo "${!parameter}"
      i=$((i + 1))
      parameter="${prefix}_${i}"
    done
  elif [[ -n "${!prefix:-}" ]]; then
    echo "${!prefix}"
  fi
}

# Read a list from plugin config by KEY.
function plugin_read_list() {
  local prefix
  prefix="$(plugin_env_prefix)"
  prefix_read_list "${prefix}_$1"
}

# Buildkite log group markers.
# Use `+++` for the "currently focused" group and `---` for collapsed.
function log_group() {
  echo "--- $*"
}

function log_focus() {
  echo "+++ $*"
}

# Print a warning (yellow) to stderr without leaking secrets.
function log_warn() {
  echo "~~~ ⚠️  $*" >&2
}

# Print a fatal error and exit 1.
function log_fatal() {
  echo "+++ 🚨 $*" >&2
  exit 1
}

# Determine if running on Windows-flavoured bash (Git Bash, MSYS, Cygwin).
function is_windows() {
  [[ "$OSTYPE" =~ ^(win|msys|cygwin) ]]
}

# Determine if running on macOS.
function is_macos() {
  [[ "$OSTYPE" =~ ^(darwin) ]]
}

# True when Buildkite exposes a numeric pull request id (PR build).
# Outside PR builds Buildkite sets BUILDKITE_PULL_REQUEST to the string "false".
function bk_pull_request_is_numeric() {
  local p="${BUILDKITE_PULL_REQUEST:-}"
  [[ -n "$p" && "$p" != "false" && "$p" =~ ^[0-9]+$ ]]
}

# True when scan will pass --bazel-include-targets (plugin key or additional_args).
function plugin_bazel_include_targets_configured() {
  if [[ -n "${ENDOR_PLUGIN_BAZEL_INCLUDE_TARGETS:-}" ]]; then
    return 0
  fi
  if [[ "${ENDOR_PLUGIN_ADDITIONAL_ARGS:-}" == *"--bazel-include-targets"* ]]; then
    return 0
  fi
  return 1
}
