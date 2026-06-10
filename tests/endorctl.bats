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
  unset ENDOR_NAMESPACE

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "'namespace' is required"
}

@test "namespace falls back to ENDOR_NAMESPACE env when plugin namespace unset" {
  unset BUILDKITE_PLUGIN_ENDORLABS_NAMESPACE
  export ENDOR_NAMESPACE=from-cluster-secret

  stub endorctl \
    "scan --namespace=from-cluster-secret --output-type=json --log-level=info --verbose=false --dependencies=true : echo 'ran scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran scan"
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

@test "BUILDKITE_PULL_REQUEST adds --pr without --scm-pr-id" {
  export BUILDKITE_BRANCH=feature/widgets
  export BUILDKITE_PULL_REQUEST=123
  export BUILDKITE_PULL_REQUEST_BASE_BRANCH=main

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --pr-baseline=main : echo 'ran pr scan'"

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
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --pr-baseline=develop : echo 'ran pr scan'"

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
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --pr-baseline=main : echo 'ran pr scan'"

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
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --detached-ref-name=feature/widgets --pr=true --pr-baseline=main --pr-incremental=true : echo 'ran incremental'"

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
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_EXCLUDE_TARGETS=//third_party:all
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_TARGETS_QUERY=kind\(go_library,//...\)

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --secrets=true --sast=true --tools=true --ghactions=true --ai-models=true --git-logs=true --phantom-dependencies=true --disable-code-snippet-storage=true --use-bazel=true --bazel-exclude-targets=//third_party:all --bazel-targets-query=kind\\(go_library,//...\\) : echo 'ran full scan'"

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
  refute_output --partial '"summary"'
}

@test "annotate=true does not echo scan JSON to stdout" {
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo '{\"all_findings\":[{\"uuid\":\"leak-me\"}]}'"
  stub buildkite-agent \
    "annotate * --style success --context endorlabs-scan : echo 'annotation sent'"

  run "$PWD"/hooks/post-command

  assert_success
  refute_output --partial "leak-me"
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

@test "findings annotation html helper renders severity and table" {
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  # shellcheck source=lib/endorctl.bash
  source "$PWD/lib/endorctl.bash"

  export ENDOR_PLUGIN_SCAN_DEPENDENCIES=true
  export ENDOR_PLUGIN_SCAN_SAST=false
  export ENDOR_PLUGIN_SCAN_SECRETS=false

  local json="${BATS_TEST_TMPDIR}/findings.json"
  cat >"${json}" <<'EOF'
{"all_findings":[{"uuid":"abc123finding","context":{"id":"dev","type":"CONTEXT_TYPE_REF"},"tenant_meta":{"namespace":"endor-solutions-tgowan"},"meta":{"description":"High vuln in pyjwt"},"spec":{"level":"FINDING_LEVEL_HIGH","project_uuid":"69d5c473190e0676d079acc7","finding_categories":["FINDING_CATEGORY_VULNERABILITY"],"target_dependency_name":"pyjwt","finding_tags":["FINDING_TAGS_POTENTIALLY_REACHABLE_DEPENDENCY","FINDING_TAGS_REACHABLE_FUNCTION","FINDING_TAGS_CI_BLOCKER","FINDING_TAGS_FIX_AVAILABLE"],"location_urls":{"pyjwt":"https://example.com/pyjwt"}}}]}
EOF

  run _build_findings_annotation_html "${json}" 5

  assert_success
  assert_output --partial "Findings (dev)"
  assert_output --partial "https://app.endorlabs.com/t/endor-solutions-tgowan/projects/69d5c473190e0676d079acc7/versions/dev/findings?filter.values="
  assert_output --partial "resourceDetail="
  assert_output --partial "findingUuid%22%3A%22abc123finding%22"
  assert_output --partial "findingNamespace%22%3A%22endor-solutions-tgowan%22"
  assert_output --partial "By severity"
  assert_output --partial "High vuln in pyjwt"
  assert_output --partial "Potentially Reachable Dependency"
  assert_output --partial "Reachable Function"
  assert_output --partial "Dep:"
  assert_output --partial "Fn:"
  assert_output --partial "<th>Reachability</th>"
  assert_output --partial "Dep = dependency in graph"
  assert_output --partial "pyjwt"
  assert_output --partial "🛑 Blocker"
  assert_output --partial "🩹 Fix available"
  assert_output --partial 'style="color:#0d9488;text-decoration:underline"'
  assert_output --partial "https://example.com/pyjwt"
  assert_output --partial "<table>"
  refute_output --partial "<th>Reach</th>"
}

@test "findings table includes all critical and high before medium/low cap" {
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  # shellcheck source=lib/endorctl.bash
  source "$PWD/lib/endorctl.bash"

  export ENDOR_PLUGIN_SCAN_DEPENDENCIES=true
  export ENDOR_PLUGIN_SCAN_SAST=false

  local json="${BATS_TEST_TMPDIR}/mixed-severity.json"
  cat >"${json}" <<'EOF'
{"all_findings":[
  {"uuid":"low1","meta":{"description":"Low issue"},"spec":{"level":"FINDING_LEVEL_LOW","finding_categories":["FINDING_CATEGORY_VULNERABILITY"],"target_dependency_name":"low-pkg"}},
  {"uuid":"med1","meta":{"description":"Medium issue"},"spec":{"level":"FINDING_LEVEL_MEDIUM","finding_categories":["FINDING_CATEGORY_SCA"],"target_dependency_name":"med-pkg"}},
  {"uuid":"med2","meta":{"description":"Medium issue two"},"spec":{"level":"FINDING_LEVEL_MEDIUM","finding_categories":["FINDING_CATEGORY_SCA"],"target_dependency_name":"med-pkg-2"}},
  {"uuid":"high1","meta":{"description":"High issue"},"spec":{"level":"FINDING_LEVEL_HIGH","finding_categories":["FINDING_CATEGORY_VULNERABILITY"],"target_dependency_name":"high-pkg"}},
  {"uuid":"crit1","meta":{"description":"Critical issue"},"spec":{"level":"FINDING_LEVEL_CRITICAL","finding_categories":["FINDING_CATEGORY_VULNERABILITY"],"target_dependency_name":"crit-pkg"}}
]}
EOF

  run _build_findings_annotation_html "${json}" 1

  assert_success
  assert_output --partial "Critical issue"
  assert_output --partial "High issue"
  assert_output --partial "Medium issue"
  refute_output --partial "Medium issue two"
  refute_output --partial "Low issue"
  assert_output --partial "Showing 3 of 5 findings"
}

@test "SAST step table has location and tags without reach or package columns" {
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  # shellcheck source=lib/endorctl.bash
  source "$PWD/lib/endorctl.bash"

  export ENDOR_PLUGIN_SCAN_DEPENDENCIES=false
  export ENDOR_PLUGIN_SCAN_SAST=true
  export ENDOR_PLUGIN_SCAN_SECRETS=false
  export ENDOR_PLUGIN_ADDITIONAL_ARGS=""

  local json="${BATS_TEST_TMPDIR}/sast.json"
  cat >"${json}" <<'EOF'
{"all_findings":[{"uuid":"sast-row","context":{"id":"dev","type":"CONTEXT_TYPE_REF"},"tenant_meta":{"namespace":"acme"},"meta":{"description":"SQL injection in handler"},"spec":{"level":"FINDING_LEVEL_HIGH","project_uuid":"proj1","finding_categories":["FINDING_CATEGORY_SAST"],"finding_metadata":{"custom":{"location":"https://github.com/acme/repo/blob/main/app.py#L42","cwes":["CWE-89: Improper Neutralization of Special Elements used in an SQL Command"]}},"finding_tags":["FINDING_TAGS_CI_BLOCKER"]}}]}
EOF

  run _build_findings_annotation_html "${json}" 5

  assert_success
  assert_output --partial "SQL injection in handler"
  assert_output --partial "<th>CWE</th>"
  assert_output --partial "CWE-89"
  assert_output --partial "<th>Location</th>"
  assert_output --partial "<th>Tags</th>"
  assert_output --partial "app.py:42"
  refute_output --partial "<th>Package</th>"
  refute_output --partial "<th>Reachability</th>"
}

@test "findings count line shows no findings emoji when zero" {
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  # shellcheck source=lib/endorctl.bash
  source "$PWD/lib/endorctl.bash"

  run _findings_count_line_html 0 0 "dependencies scan"

  assert_success
  assert_output --partial "✨ No findings for dependencies scan"
}

@test "policy counts html renders blocking and warning lists" {
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  # shellcheck source=lib/endorctl.bash
  source "$PWD/lib/endorctl.bash"

  export ENDOR_PLUGIN_SCAN_DEPENDENCIES=true
  export ENDOR_PLUGIN_SCAN_SAST=false

  local json="${BATS_TEST_TMPDIR}/policy.json"
  cat >"${json}" <<'EOF'
{"blocking_findings":[
  {"spec":{"finding_categories":["FINDING_CATEGORY_VULNERABILITY"],"level":"FINDING_LEVEL_HIGH"}},
  {"spec":{"finding_categories":["FINDING_CATEGORY_SCA"],"level":"FINDING_LEVEL_MEDIUM"}}
],"warning_findings":[
  {"spec":{"finding_categories":["FINDING_CATEGORY_VULNERABILITY"],"level":"FINDING_LEVEL_LOW"}}
]}
EOF

  run _build_policy_counts_html "${json}"

  assert_success
  assert_output --partial "📊 Policy findings (this scan)"
  assert_output --partial "🛑 2 blocking"
  assert_output --partial "⚠️ 1 policy warnings"
}

@test "dependencies step filters out SAST findings and SAST admission warnings" {
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  # shellcheck source=lib/endorctl.bash
  source "$PWD/lib/endorctl.bash"

  export ENDOR_PLUGIN_SCAN_DEPENDENCIES=true
  export ENDOR_PLUGIN_SCAN_SAST=false
  export ENDOR_PLUGIN_SCAN_SECRETS=false

  local json="${BATS_TEST_TMPDIR}/mixed.json"
  cat >"${json}" <<'EOF'
{"warnings":["Changes violate admission policy: SAST","Changes violate admission policy: Vulnerabilities"],"all_findings":[
  {"uuid":"sast1","meta":{"description":"AI SAST issue"},"spec":{"level":"FINDING_LEVEL_HIGH","finding_categories":["FINDING_CATEGORY_SAST"],"finding_tags":["FINDING_TAGS_AI"]}},
  {"uuid":"sca1","meta":{"description":"CVE in libfoo"},"spec":{"level":"FINDING_LEVEL_MEDIUM","finding_categories":["FINDING_CATEGORY_VULNERABILITY"],"target_dependency_name":"libfoo"}}
]}
EOF

  run _build_findings_annotation_html "${json}" 10

  assert_success
  refute_output --partial "AI SAST issue"
  assert_output --partial "CVE in libfoo"

  run _build_admission_warnings_html "${json}"
  assert_success
  assert_output --partial "Vulnerabilities"
  refute_output --partial "SAST"
}

@test "endor project link uses pr-runs path for CI run context" {
  # shellcheck source=lib/shared.bash
  source "$PWD/lib/shared.bash"
  # shellcheck source=lib/endorctl.bash
  source "$PWD/lib/endorctl.bash"

  local json="${BATS_TEST_TMPDIR}/pr-run.json"
  echo '{"blocking_findings":[{"context":{"id":"pr-uuid-99","type":"CONTEXT_TYPE_CI_RUN"},"tenant_meta":{"namespace":"acme-ns"},"spec":{"project_uuid":"proj001"}}]}' >"${json}"

  run _build_endor_project_link_html "${json}"

  assert_success
  assert_output --partial "Findings (PR pr-uuid-99)"
  assert_output --partial "https://app.endorlabs.com/t/acme-ns/projects/proj001/pr-runs/pr-uuid-99/findings?filter.values="
}

@test "annotate_scope=job passes --scope job to buildkite-agent" {
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE_SCOPE=job

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo '{\"summary\":{\"findings\":{\"total\":1}}}'"
  stub buildkite-agent \
    "annotate * --style success --context endorlabs-scan --scope job : echo 'job annotation'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "job annotation"
  unstub buildkite-agent
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
  # Credentials are exported, not passed as CLI args.
  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo \"\$*\""

  run "$PWD"/hooks/post-command

  assert_success
  refute_output --partial "kkkkkkkk"
  refute_output --partial "ssssssss"
  refute_output --partial "--api-key"
  refute_output --partial "--api-secret"
  refute_output --partial "--token"
}

@test "configure_auth unsets ENDOR_TOKEN when using API key mode" {
  export ENDOR_TOKEN=conflict-bearer-token

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo ok"

  run "$PWD"/hooks/post-command

  assert_success
  refute_output --partial "conflict-bearer-token"
}

@test "pre-exported ENDOR_API_CREDENTIALS_* works without api_key_env" {
  unset BUILDKITE_PLUGIN_ENDORLABS_API_KEY_ENV
  unset BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV
  unset FAKE_KEY
  unset FAKE_SECRET
  export ENDOR_API_CREDENTIALS_KEY=kkkkkkkk
  export ENDOR_API_CREDENTIALS_SECRET=ssssssss

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo pre-exported-ok"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "pre-exported-ok"
}

@test "soft_fail=true does not soften policy exit 128 when fail_on_policy is true" {
  export BUILDKITE_PLUGIN_ENDORLABS_SOFT_FAIL=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : exit 128"

  run "$PWD"/hooks/post-command

  assert_failure
  refute_output --partial "soft_fail=true"
}

@test "annotate=true uses error style for policy exit 128" {
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true
  export BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE="${BATS_TEST_TMPDIR}/endor-out.json"
  echo '{"summary":{"findings":{"total":1}}}' >"${BUILDKITE_PLUGIN_ENDORLABS_OUTPUT_FILE}"

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : exit 128"
  stub buildkite-agent \
    "annotate * --style error --context endorlabs-scan : echo 'policy annotate'"

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "policy annotate"
}

@test "annotate=true warns and continues when buildkite-agent is missing" {
  export BUILDKITE_PLUGIN_ENDORLABS_ANNOTATE=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo scan-ok"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "scan-ok"
  assert_output --partial "buildkite-agent is not available; skipping annotation"
}

@test "upload_artifacts warns when artifact path is missing" {
  export BUILDKITE_PLUGIN_ENDORLABS_UPLOAD_ARTIFACTS=true
  export BUILDKITE_PLUGIN_ENDORLABS_ARTIFACT_PATHS="${BATS_TEST_TMPDIR}/missing-artifact.json"

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo scan-ok"
  stub buildkite-agent \
    "artifact upload * : echo should-not-upload"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "artifact path not found"
  assert_output --partial "scan-ok"
  refute_output --partial "should-not-upload"
}

@test "fails when no scan kind is enabled" {
  export BUILDKITE_PLUGIN_ENDORLABS_SCAN_DEPENDENCIES=false

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "at least one scan kind must be enabled"
}

@test "fails when API key is set without secret" {
  unset BUILDKITE_PLUGIN_ENDORLABS_API_SECRET_ENV
  unset FAKE_SECRET
  export FAKE_KEY=kkkkkkkk

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "api key auth requires both key and secret"
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

@test "soft_fail=true converts non-policy endorctl exit to success" {
  export BUILDKITE_PLUGIN_ENDORLABS_SOFT_FAIL=true

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : exit 4"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "soft_fail=true"
}

@test "post-command sources BUILDKITE_ENV_FILE before running scan" {
  export BUILDKITE_ENV_FILE="${BATS_TEST_TMPDIR}/bk-step.env"
  echo "CUSTOM_PLUGIN_ENV_MARKER=from-step" >"${BUILDKITE_ENV_FILE}"

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true : echo env=\${CUSTOM_PLUGIN_ENV_MARKER:-missing}"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "env=from-step"
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

@test "bazel_targets_query omitted when additional_args sets bazel-include-targets" {
  export BUILDKITE_PLUGIN_ENDORLABS_USE_BAZEL=true
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_TARGETS_QUERY=kind\(go_library,//...\)
  export BUILDKITE_PLUGIN_ENDORLABS_ADDITIONAL_ARGS="--use-bazel-aspects --bazel-include-targets=//app:main"

  stub endorctl \
    "scan --namespace=demo --output-type=json --log-level=info --verbose=false --dependencies=true --use-bazel=true --use-bazel-aspects --bazel-include-targets=//app:main : echo 'ran aspects scan'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial "ran aspects scan"
}

@test "bazel_include_targets and bazel_targets_query together fail validation" {
  export BUILDKITE_PLUGIN_ENDORLABS_USE_BAZEL=true
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_INCLUDE_TARGETS=//app:all
  export BUILDKITE_PLUGIN_ENDORLABS_BAZEL_TARGETS_QUERY=kind\(go_library,//...\)

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial "bazel_include_targets and bazel_targets_query are mutually exclusive"
}
