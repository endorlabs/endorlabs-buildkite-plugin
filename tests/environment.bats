#!/usr/bin/env bats

# Step-environment helpers (BUILDKITE_ENV_FILE, BUILDKITE_TOOL_DIR, MSYS on Windows).

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  unset BUILDKITE_ENV_FILE
  unset BUILDKITE_TOOL_DIR
  unset MSYS_NO_PATHCONV
  unset CUSTOM_PLUGIN_ENV_MARKER
}

@test "plugin_load_step_environment sources BUILDKITE_ENV_FILE" {
  export BUILDKITE_ENV_FILE="${BATS_TEST_TMPDIR}/step.env"
  echo 'CUSTOM_PLUGIN_ENV_MARKER=sourced' >"${BUILDKITE_ENV_FILE}"

  plugin_load_step_environment

  [ "${CUSTOM_PLUGIN_ENV_MARKER}" = "sourced" ]
}

@test "plugin_load_step_environment ignores unset or missing env file" {
  unset BUILDKITE_ENV_FILE

  run plugin_load_step_environment
  assert_success

  export BUILDKITE_ENV_FILE="${BATS_TEST_TMPDIR}/missing.env"
  run plugin_load_step_environment
  assert_success
}

@test "plugin_load_step_environment prepends BUILDKITE_TOOL_DIR to PATH" {
  export BUILDKITE_TOOL_DIR="${BATS_TEST_TMPDIR}/tools"
  mkdir -p "${BUILDKITE_TOOL_DIR}"

  plugin_load_step_environment

  [[ ":${PATH}:" == *":${BUILDKITE_TOOL_DIR}:"* ]]
}

@test "plugin_load_step_environment sets MSYS_NO_PATHCONV on Windows bash" {
  unset MSYS_NO_PATHCONV
  export OSTYPE=msys
  plugin_load_step_environment
  [ "${MSYS_NO_PATHCONV}" = "1" ]
}

@test "post-command sets MSYS_NO_PATHCONV before loading libraries on msys" {
  export BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE=demo
  export BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV=FAKE_KEY
  export BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV=FAKE_SECRET
  export FAKE_KEY=kkkkkkkk
  export FAKE_SECRET=ssssssss
  export BUILDKITE_PLUGIN_ENDORLABS_ENDORCTL_SKIP_INSTALL=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo MSYS_NO_PATHCONV=\${MSYS_NO_PATHCONV:-unset}"

  OSTYPE=msys run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "MSYS_NO_PATHCONV=1"
  unstub endorctl
}
