#!/usr/bin/env bats

# Verifies the endorctl install path:
#   1. curl /meta/version to discover latest version + checksums
#   2. curl the binary
#   3. sha256 verify
#   4. place on PATH and exec scan
#
# We replace curl with a stub that returns a fixed version JSON and copies
# a pre-built "fake endorctl" shell script to the download destination.
# The fake binary's actual sha256 is embedded into the version JSON so the
# real sha256 check inside lib/endorctl.bash passes.

setup_file() {
  export INSTALL_FIXTURE_DIR="${BATS_FILE_TMPDIR}/endorlabs-fixture"
  mkdir -p "${INSTALL_FIXTURE_DIR}"

  cat > "${INSTALL_FIXTURE_DIR}/endorctl" <<'BIN'
#!/bin/sh
echo "fake-endorctl invoked: $*"
BIN
  chmod +x "${INSTALL_FIXTURE_DIR}/endorctl"

  INSTALL_FIXTURE_HASH=$(sha256sum "${INSTALL_FIXTURE_DIR}/endorctl" | awk '{print $1}')
  export INSTALL_FIXTURE_HASH

  cat > "${INSTALL_FIXTURE_DIR}/version.json" <<EOF
{
  "ClientVersion": "9.9.9",
  "Service": { "Version": "9.9.9" },
  "ClientChecksums": {
    "ARCH_TYPE_LINUX_AMD64": "${INSTALL_FIXTURE_HASH}",
    "ARCH_TYPE_LINUX_ARM64": "${INSTALL_FIXTURE_HASH}",
    "ARCH_TYPE_MACOS_AMD64": "${INSTALL_FIXTURE_HASH}",
    "ARCH_TYPE_MACOS_ARM64": "${INSTALL_FIXTURE_HASH}",
    "ARCH_TYPE_WINDOWS_AMD64": "${INSTALL_FIXTURE_HASH}"
  }
}
EOF
}

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # export CURL_STUB_DEBUG=/dev/tty

  export BUILDKITE_JOB_ID=test-job
  export BUILDKITE_PIPELINE_SLUG=test-pipeline
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PULL_REQUEST=false
  unset BUILDKITE_BRANCH
  unset BUILDKITE_PULL_REQUEST_BASE_BRANCH

  export BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE=demo
  export BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV=FAKE_KEY
  export BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV=FAKE_SECRET
  export FAKE_KEY="kkkkkkkk"
  export FAKE_SECRET="ssssssss"

  # Isolated install dir per test.
  export BUILDKITE_PLUGIN_ENDORLABS_INSTALL_DIR="${BATS_TEST_TMPDIR}/endorlabs-install"

  # endorctl must NOT be on PATH for the install path to run; the bats-mock
  # binstub dir is at the front of PATH, so as long as we don't stub
  # endorctl, lib/endorctl.bash will execute its install codepath.
}

teardown() {
  unstub curl || true
}

@test "downloads endorctl from /meta/version when no version is pinned" {
  stub curl \
    "-fsSL https://api.endorlabs.com/meta/version : cat '${INSTALL_FIXTURE_DIR}/version.json'" \
    "-fsSL -o * * : cp '${INSTALL_FIXTURE_DIR}/endorctl' \"\$3\""

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "Downloading endorctl 9.9.9"
  assert_output --partial "fake-endorctl invoked: scan --namespace=demo"
}

@test "rejects download when sha256 does not match the published checksum" {
  # Pin a wrong checksum so verification fails after download.
  export BUILDKITE_PLUGIN_ENDORLABS_ENDORCTL_VERSION=9.9.9
  export BUILDKITE_PLUGIN_ENDORLABS_ENDORCTL_CHECKSUM=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef

  stub curl \
    "-fsSL -o * * : cp '${INSTALL_FIXTURE_DIR}/endorctl' \"\$3\""

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "checksum mismatch"
}
