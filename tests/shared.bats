#!/usr/bin/env bash

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  PLUGIN_ENV_PREFIX=""
  unset BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE
  unset BUILDKITE_PLUGIN_ENDORLABS_BUILDKITE_PLUGIN_NAMESPACE
  unset BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE
  unset BUILDKITE_PLUGIN_ENDORLABS_BUILDKITE_PLUGIN_ANNOTATE
}

@test "plugin_read_config uses endorlabs# plugin id prefix" {
  export BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE=from-marketplace
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true

  run plugin_read_config NAMESPACE
  assert_success
  assert_output "from-marketplace"

  run plugin_read_config ANNOTATE "false"
  assert_success
  assert_output "true"
}

@test "plugin_read_config uses vendored directory plugin id prefix" {
  export BUILDKITE_PLUGIN_ENDORLABS_BUILDKITE_PLUGIN_NAMESPACE=from-vendor-path
  export BUILDKITE_PLUGIN_ENDORLABS_BUILDKITE_PLUGIN_ANNOTATE=true

  run plugin_read_config NAMESPACE
  assert_success
  assert_output "from-vendor-path"

  run plugin_read_config ANNOTATE "false"
  assert_success
  assert_output "true"
}
