#!/bin/bash

# Shared helpers for the Endor Labs Buildkite plugin.
#
# Patterns mirror buildkite-plugins/docker-compose-buildkite-plugin:
# - plugin_read_config: read BUILDKITE_PLUGIN_ENDORLABS_<KEY> with optional default
# - plugin_read_list / prefix_read_list: handle YAML array → KEY_0, KEY_1, ...
# - log_group / log_subgroup: Buildkite collapsible group markers (--- / +++)

# Read a single plugin config value by KEY (uppercase, underscored).
# Usage: plugin_read_config NAMESPACE
#        plugin_read_config SCAN_PATH "."
function plugin_read_config() {
  local var="BUILDKITE_PLUGIN_ENDORLABS_${1}"
  local default="${2:-}"
  echo "${!var:-$default}"
}

# Return success if a plugin config key is set (even to empty string).
function plugin_config_exists() {
  local var="BUILDKITE_PLUGIN_ENDORLABS_${1}"
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
  prefix_read_list "BUILDKITE_PLUGIN_ENDORLABS_$1"
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
