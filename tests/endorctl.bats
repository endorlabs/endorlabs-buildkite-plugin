#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to debug stub matches.
  # export ENDORCTL_STUB_DEBUG=/dev/tty
  # export CURL_STUB_DEBUG=/dev/tty

  # Baseline Buildkite env that real agents always populate.
  export BUILDKITE_JOB_ID=test-job
  export BUILDKITE_PIPELINE_SLUG=test-pipeline
  export BUILDKITE_BUILD_NUMBER=1

  # Defensive: a real Buildkite agent sets BUILDKITE_PULL_REQUEST="false"
  # outside PR builds. Mirror that so happy-path tests don't accidentally
  # flip into the PR code path if the host env leaks through.
  export BUILDKITE_PULL_REQUEST=false
  unset BUILDKITE_BRANCH
  unset BUILDKITE_PULL_REQUEST_BASE_BRANCH

  # Common plugin config.
  export BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE=demo
  export BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV=FAKE_KEY
  export BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV=FAKE_SECRET
  export FAKE_KEY="kkkkkkkk"
  export FAKE_SECRET="ssssssss"

  # Skip the network install by default; install path has its own test.
  export BUILDKITE_PLUGIN_ENDORLABS_ENDORCTL_SKIP_INSTALL=true
}

teardown() {
  unstub endorctl || true
  unstub curl || true
  unstub buildkite-agent || true
}

@test "fails when neither api_key_env nor ENDOR_API_CREDENTIALS_KEY are set" {
  unset BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV
  unset BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV
  unset ENDOR_API_CREDENTIALS_KEY
  unset ENDOR_API_CREDENTIALS_SECRET

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "API credentials not found"
  refute_output --partial "kkkkkkkk"
  refute_output --partial "ssssssss"
}

@test "aws_role_arn auth mode bypasses api key requirement and adds flag" {
  unset BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV
  unset BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV
  unset ENDOR_API_CREDENTIALS_KEY
  unset ENDOR_API_CREDENTIALS_SECRET
  export BUILDKITE_PLUGIN_ENDORLABS_AWS_ROLE_ARN="arn:aws:iam::123456789012:role/endorlabs-federation-role"

  stub endorctl \
    "scan --namespace=demo --aws-role-arn=arn:aws:iam::123456789012:role/endorlabs-federation-role --output-type=json --log-level=info --verbose=false --dependencies=true : echo 'ran aws auth scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran aws auth scan"
}

@test "enable_azure_managed_identity auth mode bypasses api key requirement and adds flag" {
  unset BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV
  unset BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV
  unset ENDOR_API_CREDENTIALS_KEY
  unset ENDOR_API_CREDENTIALS_SECRET
  export BUILDKITE_PLUGIN_ENDORLABS_ENABLE_AZURE_MANAGED_IDENTITY=true

  stub endorctl \
    "scan --namespace=demo --enable-azure-managed-identity --output-type=json --log-level=info --verbose=false --dependencies=true : echo 'ran azure auth scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran azure auth scan"
}

@test "gcp_service_account auth mode bypasses api key requirement and adds flag" {
  unset BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV
  unset BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV
  unset ENDOR_API_CREDENTIALS_KEY
  unset ENDOR_API_CREDENTIALS_SECRET
  export BUILDKITE_PLUGIN_ENDORLABS_GCP_SERVICE_ACCOUNT="endorlabs-federation@my-project.iam.gserviceaccount.com"

  stub endorctl \
    "scan --namespace=demo --gcp-service-account=endorlabs-federation@my-project.iam.gserviceaccount.com --output-type=json --log-level=info --verbose=false --dependencies=true : echo 'ran gcp auth scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran gcp auth scan"
}

@test "fails when multiple auth modes are configured" {
  export BUILDKITE_PLUGIN_ENDORLABS_AWS_ROLE_ARN="arn:aws:iam::123456789012:role/endorlabs-federation-role"

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "provide exactly one auth mode"
}

@test "fails when namespace is missing" {
  unset BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "'namespace' is required"
}

@test "fails when endorctl_version is pinned without checksum" {
  export BUILDKITE_PLUGIN_ENDORLABS_ENDORCTL_VERSION=1.2.3
  unset BUILDKITE_PLUGIN_ENDORLABS_ENDORCTL_CHECKSUM

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "'endorctl_checksum' is required"
}

@test "happy path runs endorctl scan with --dependencies=true" {
  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo 'ran scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran scan"
  assert_output --partial "Running endorctl scan"
}

@test "BUILDKITE_BRANCH is mapped to --detached-ref-name" {
  export BUILDKITE_BRANCH=feature/widgets

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets : echo 'ran scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran scan"
}

@test "BUILDKITE_PULL_REQUEST adds --pr and --scm-pr-id" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PULL_REQUEST_BASE_BRANCH=main

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --scm-pr-id=123 --pr-baseline=main : echo 'ran pr scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran pr scan"
}

@test "pr false disables PR flags even when BUILDKITE_PULL_REQUEST is numeric" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PULL_REQUEST_BASE_BRANCH=main
  export BUILDKITE_PLUGIN_ENDORLABS_PR=false

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets : echo 'ran non-pr scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran non-pr scan"
}

@test "pr_baseline config overrides BUILDKITE_PULL_REQUEST_BASE_BRANCH" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PULL_REQUEST_BASE_BRANCH=main
  export BUILDKITE_PLUGIN_ENDORLABS_PR_BASELINE=develop

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --scm-pr-id=123 --pr-baseline=develop : echo 'ran pr scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran pr scan"
}

@test "BUILDKITE_PULL_REQUEST_BASE_BRANCH used when pr_baseline unset" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PULL_REQUEST_BASE_BRANCH=main
  unset BUILDKITE_PLUGIN_ENDORLABS_PR_BASELINE

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --scm-pr-id=123 --pr-baseline=main : echo 'ran pr scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran pr scan"
}

@test "pr_incremental adds --pr-incremental when PR context and baseline exist" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PULL_REQUEST_BASE_BRANCH=main
  export BUILDKITE_PLUGIN_ENDORLABS_PR_INCREMENTAL=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --scm-pr-id=123 --pr-baseline=main --pr-incremental=true : echo 'ran incremental'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran incremental"
}

@test "pr_incremental fails fast without PR id or pr_baseline" {
  export BUILDKITE_PLUGIN_ENDORLABS_PR_INCREMENTAL=true

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "pr_incremental requires a numeric BUILDKITE_PULL_REQUEST or pr_baseline"
}

@test "pr_incremental fails fast without baseline when comments are disabled" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  unset BUILDKITE_PULL_REQUEST_BASE_BRANCH
  export BUILDKITE_PLUGIN_ENDORLABS_PR_INCREMENTAL=true

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "pr_incremental requires pr_baseline, BUILDKITE_PULL_REQUEST_BASE_BRANCH, or enable_pr_comments=true"
}

@test "enable_pr_comments requires scm_token_env" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PLUGIN_ENDORLABS_ENABLE_PR_COMMENTS=true

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "enable_pr_comments requires scm_token_env"
}

@test "enable_pr_comments requires non-empty token from scm_token_env" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PLUGIN_ENDORLABS_ENABLE_PR_COMMENTS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCM_TOKEN_ENV=EMPTY_SCM_TOKEN
  export EMPTY_SCM_TOKEN=""

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "enable_pr_comments requires env var 'EMPTY_SCM_TOKEN'"
}

@test "enable_pr_comments adds flags without leaking scm token in output" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PLUGIN_ENDORLABS_ENABLE_PR_COMMENTS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCM_TOKEN_ENV=SCM_SECRET_ENV
  export SCM_SECRET_ENV="glpat-super-secret-token-value"

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --scm-pr-id=123 --enable-pr-comments=true --scm-token=glpat-super-secret-token-value : echo 'ran comments scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran comments scan"
  refute_output --partial "glpat-super-secret-token-value"
}

@test "enable_pr_comments fails outside numeric pull-request context" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PLUGIN_ENDORLABS_ENABLE_PR_COMMENTS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCM_TOKEN_ENV=SCM_SECRET_ENV
  export SCM_SECRET_ENV="tokenvalue"

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "enable_pr_comments requires a pull-request build"
}

@test "enable_pr_comments fails with pr false on a pull-request build" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PLUGIN_ENDORLABS_PR=false
  export BUILDKITE_PLUGIN_ENDORLABS_ENABLE_PR_COMMENTS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCM_TOKEN_ENV=SCM_SECRET_ENV
  export SCM_SECRET_ENV="tokenvalue"

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "enable_pr_comments cannot be used with pr: false"
}

@test "pr_incremental with enable_pr_comments does not require BUILDKITE_PULL_REQUEST_BASE_BRANCH" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  unset BUILDKITE_PULL_REQUEST_BASE_BRANCH
  export BUILDKITE_PLUGIN_ENDORLABS_PR_INCREMENTAL=true
  export BUILDKITE_PLUGIN_ENDORLABS_ENABLE_PR_COMMENTS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCM_TOKEN_ENV=SCM_SECRET_ENV
  export SCM_SECRET_ENV="tokenvalue"

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --scm-pr-id=123 --pr-incremental=true --enable-pr-comments=true --scm-token=tokenvalue : echo 'ran incremental comments'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran incremental comments"
}

@test "additional_args are appended verbatim" {
  export BUILDKITE_PLUGIN_ENDORLABS_ADDITIONAL_ARGS="--phantom-dependencies=true --tools=true"

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --phantom-dependencies=true --tools=true : echo 'ran scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran scan"
}

@test "scan_dependencies=false omits --dependencies flag" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_SECRETS=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --secrets=true : echo 'ran scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran scan"
}

@test "scan toggles wire to endorctl flags" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_SECRETS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_SAST=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_GITHUB_ACTIONS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_AI_MODELS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_GIT_LOGS=true
  export BUILDKITE_PLUGIN_ENDORLABS_PHANTOM_DEPENDENCIES=true
  export BUILDKITE_PLUGIN_ENDORLABS_DISABLE_CODE_SNIPPET_STORAGE=true
  export BUILDKITE_PLUGIN_ENDORLABS_USE_BAZEL=true
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_INCLUDE_TARGETS=//app:all
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_EXCLUDE_TARGETS=//third_party:all
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_TARGETS_QUERY=kind\(go_library,//...\)

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --secrets=true --sast=true --tools=true --ghactions=true --ai-models=true --git-logs=true --phantom-dependencies=true --disable-code-snippet-storage=true --use-bazel=true --bazel-include-targets=//app:all --bazel-exclude-targets=//third_party:all --bazel-targets-query=kind\\(go_library,//...\\) : echo 'ran full scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran full scan"
}

@test "scan_package adds package and project-name flags" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_PACKAGE=true
  export BUILDKITE_PLUGIN_ENDORLABS_PROJECT_NAME=demo-artifact
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_PATH=dist/demo.tar.gz

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --package=true --project-name=demo-artifact --path=dist/demo.tar.gz : echo 'ran package scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran package scan"
}

@test "invalid combo scan_package + scan_dependencies fails fast" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_PACKAGE=true
  export BUILDKITE_PLUGIN_ENDORLABS_PROJECT_NAME=demo-artifact
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_PATH=dist/demo.tar.gz

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "scan_package and scan_dependencies cannot be enabled together"
}

@test "scan_ai_models requires scan_dependencies" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_AI_MODELS=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_TOOLS=true

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "scan_ai_models requires scan_dependencies=true"
}

@test "scan_git_logs requires scan_secrets" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_GIT_LOGS=true

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "scan_git_logs requires scan_secrets=true"
}

@test "disable_code_snippet_storage requires scan_sast" {
  export BUILDKITE_PLUGIN_ENDORLABS_DISABLE_CODE_SNIPPET_STORAGE=true

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "disable_code_snippet_storage requires scan_sast=true"
}

@test "annotate defaults to false" {
  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo '{\"summary\":{\"findings\":{\"total\":2}}}'"
  stub buildkite-agent \
    "annotate * --style success --context endorlabs-scan : echo 'annotation sent'"

  run "$PWD"/hooks/post-command

  assert_success
  refute_output --partial "annotation sent"
}

@test "annotate=true calls buildkite-agent annotate with safe summary" {
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo '{\"summary\":{\"findings\":{\"total\":3}}}'"
  stub buildkite-agent \
    "annotate * --style success --context endorlabs-scan : echo 'annotation sent'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "annotation sent"
}

@test "annotate=true uses endorlabs-container context for container scan" {
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER=true
  export BUILDKITE_PLUGIN_ENDORLABS_IMAGE=alpine:3.19

  stub endorctl \
    "container scan --namespace=demo --output-type=json --log-level=info --verbose=false --image=alpine:3.19 --path=. : echo '{\"summary\":{\"findings\":{\"total\":1}}}'"
  stub buildkite-agent \
    "annotate * --style success --context endorlabs-container : echo 'annotation sent'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "annotation sent"
}

@test "annotate_context overrides default scan context" {
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE_CONTEXT=endorlabs-bk-filesystem

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo '{\"summary\":{\"findings\":{\"total\":2}}}'"
  stub buildkite-agent \
    "annotate * --style success --context endorlabs-bk-filesystem : echo 'annotation sent'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "annotation sent"
}

@test "api, scan_path, tags, sarif_file and exit_on_policy_warning all surface as flags" {
  export BUILDKITE_PLUGIN_ENDORLABS_API=https://staging.api.endorlabs.com
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_PATH=services/api
  export BUILDKITE_PLUGIN_ENDORLABS_TAGS=team=core,env=ci
  export BUILDKITE_PLUGIN_ENDORLABS_SARIF_FILE=endor.sarif
  export BUILDKITE_PLUGIN_ENDORLABS_EXIT_ON_POLICY_WARNING=true

  stub endorctl \
    "scan --namespace=demo --api=https://staging.api.endorlabs.com --output-type=json --log-level=info --verbose=false --dependencies=true --path=services/api --tags=team=core,env=ci --sarif-file=endor.sarif --exit-on-policy-warning : echo 'ran scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran scan"
}

@test "configure_auth exports ENDOR_API_CREDENTIALS_KEY without echoing secret values" {
  # Run a single scan and capture combined output. Secret values must never
  # appear in plugin output (they are exported, not passed as CLI args).
  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo 'ran scan'"

  run "$PWD"/hooks/post-command

  assert_success
  refute_output --partial "kkkkkkkk"
  refute_output --partial "ssssssss"
}

@test "container scan runs endorctl container scan with mapped flags" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER=true
  export BUILDKITE_PLUGIN_ENDORLABS_IMAGE=ghcr.io/acme/demo:1.2.3
  export BUILDKITE_PLUGIN_ENDORLABS_PROJECT_NAME=container-demo
  export BUILDKITE_PLUGIN_ENDORLABS_PROJECT_TAGS=team=core,env=ci
  export BUILDKITE_PLUGIN_ENDORLABS_CONTAINER_SCAN_PATH=services/api
  export BUILDKITE_PLUGIN_ENDORLABS_AS_REF=true
  export BUILDKITE_PLUGIN_ENDORLABS_OS_REACHABILITY=true
  export BUILDKITE_PLUGIN_ENDORLABS_PROFILING_DATA_DIR=.endor/profiles

  stub endorctl \
    "container scan --namespace=demo --output-type=json --log-level=info --verbose=false --image=ghcr.io/acme/demo:1.2.3 --as-ref --os-reachability --project-name=container-demo --project-tags=team=core,env=ci --path=services/api --profiling-data-dir=.endor/profiles : echo 'ran container scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran container scan"
}

@test "container scan fails when both image and image_tar are configured" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER=true
  export BUILDKITE_PLUGIN_ENDORLABS_IMAGE=ghcr.io/acme/demo:1.2.3
  export BUILDKITE_PLUGIN_ENDORLABS_IMAGE_TAR=/tmp/demo.tar

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "image and image_tar are mutually exclusive"
}

@test "container scan fails when combined with repository scan kinds" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_CONTAINER=true
  export BUILDKITE_PLUGIN_ENDORLABS_IMAGE=ghcr.io/acme/demo:1.2.3

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "scan_container cannot be combined with repository/package scan kinds"
}

@test "sign mode runs endorctl artifact sign" {
  export BUILDKITE_PLUGIN_ENDORLABS_MODE=sign
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_ARTIFACT_NAME=ghcr.io/acme/demo@sha256:abc
  export BUILDKITE_PLUGIN_ENDORLABS_SOURCE_REPOSITORY_REF=refs/heads/main
  export BUILDKITE_PLUGIN_ENDORLABS_CERTIFICATE_OIDC_ISSUER=https://token.actions.githubusercontent.com
  export BUILDKITE_PLUGIN_ENDORLABS_SOURCE_REPOSITORY=acme/demo
  export BUILDKITE_PLUGIN_ENDORLABS_SOURCE_REPOSITORY_OWNER=acme

  stub endorctl \
    "artifact sign --namespace=demo --log-level=info --verbose=false --name=ghcr.io/acme/demo@sha256:abc --source-repository-ref=refs/heads/main --certificate-oidc-issuer=https://token.actions.githubusercontent.com --source-repository=acme/demo --source-repository-owner=acme : echo 'ran artifact sign'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran artifact sign"
}

@test "sign mode fails fast when source_repository_ref is missing" {
  export BUILDKITE_PLUGIN_ENDORLABS_MODE=sign
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_ARTIFACT_NAME=ghcr.io/acme/demo@sha256:abc
  export BUILDKITE_PLUGIN_ENDORLABS_CERTIFICATE_OIDC_ISSUER=https://token.actions.githubusercontent.com
  unset BUILDKITE_PLUGIN_ENDORLABS_SOURCE_REPOSITORY_REF

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "source_repository_ref is required when mode=sign"
}

@test "verify mode runs endorctl artifact verify" {
  export BUILDKITE_PLUGIN_ENDORLABS_MODE=verify
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false
  export BUILDKITE_PLUGIN_ENDORLABS_ARTIFACT_NAME=ghcr.io/acme/demo@sha256:abc
  export BUILDKITE_PLUGIN_ENDORLABS_CERTIFICATE_OIDC_ISSUER=https://token.actions.githubusercontent.com

  stub endorctl \
    "artifact verify --namespace=demo --log-level=info --verbose=false --name=ghcr.io/acme/demo@sha256:abc --certificate-oidc-issuer=https://token.actions.githubusercontent.com : echo 'ran artifact verify'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran artifact verify"
}

@test "verify mode rejects scan configuration keys" {
  export BUILDKITE_PLUGIN_ENDORLABS_MODE=verify
  export BUILDKITE_PLUGIN_ENDORLABS_ARTIFACT_NAME=ghcr.io/acme/demo@sha256:abc
  export BUILDKITE_PLUGIN_ENDORLABS_CERTIFICATE_OIDC_ISSUER=https://token.actions.githubusercontent.com
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=true

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "scan_* options are only valid in mode=scan"
}

@test "fail_on_policy=false converts exit code 128 to success" {
  export BUILDKITE_PLUGIN_ENDORLABS_FAIL_ON_POLICY=false

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : exit 128"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "fail_on_policy=false"
}

@test "upload_artifacts uploads output_file when enabled" {
  export BUILDKITE_PLUGIN_ENDORLABS_UPLOAD_ARTIFACTS=true
  export BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE=endor-output.json

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo '{\"ok\":true}'"
  stub buildkite-agent \
    "artifact upload endor-output.json : echo 'artifact uploaded'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "artifact uploaded"
}
