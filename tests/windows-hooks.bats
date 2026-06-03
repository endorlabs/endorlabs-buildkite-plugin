#!/usr/bin/env bats

# Windows hook entrypoints (.bat / .ps1) delegate to hooks/post-command (Bash).
# CI runs on Linux; we verify wrapper contracts, not cmd.exe execution.

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
}

@test "post-command.bat exists and invokes bash on the extensionless hook" {
  [ -f "${BATS_TEST_DIRNAME}/../hooks/post-command.bat" ]
  grep -qE 'bash.*post-command' "${BATS_TEST_DIRNAME}/../hooks/post-command.bat"
  grep -q 'bash is required on Windows' "${BATS_TEST_DIRNAME}/../hooks/post-command.bat"
}

@test "post-command.ps1 exists and invokes bash on the extensionless hook" {
  [ -f "${BATS_TEST_DIRNAME}/../hooks/post-command.ps1" ]
  grep -q "post-command" "${BATS_TEST_DIRNAME}/../hooks/post-command.ps1"
  grep -q 'bash is required on Windows' "${BATS_TEST_DIRNAME}/../hooks/post-command.ps1"
}

@test "Windows wrappers run post-command when bash is on PATH" {
  export BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE=demo
  export BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV=FAKE_KEY
  export BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV=FAKE_SECRET
  export FAKE_KEY=kkkkkkkk
  export FAKE_SECRET=ssssssss
  export BUILDKITE_PLUGIN_ENDORLABS_ENDORCTL_SKIP_INSTALL=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo wrapper-delegation-ok"

  # Same steps as post-command.bat: plugin root + bash hooks/post-command
  cd "${BATS_TEST_DIRNAME}/.." || exit 1
  run bash "${BATS_TEST_DIRNAME}/../hooks/post-command"

  assert_success
  assert_output --partial "wrapper-delegation-ok"
  unstub endorctl
}
