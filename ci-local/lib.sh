# Shared step functions, one per Jenkinsfile stage, derived directly from
# ../Jenkinsfile: same commands, same order, same guaranteed-cleanup pairing
# (pre_integration_test/test.integration/post_integration_test and
# pre_e2e_test/test.e2e/post_e2e_test) as Jenkins' `post { always { ... } }`
# gives for free. Meant to be sourced by the case scripts in this directory
# (feature-branch.sh, devel-branch.sh, release-branch.sh, master-branch.sh),
# not run directly.
#
# POSIX sh only: no bashisms (no `local`, no `[[ ]]`, no arrays, no
# `set -o pipefail`), so this also runs under dash/ash, not just bash.

ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$ROOT_DIR" || exit 1

step() {
  echo ""
  echo "=== $1 ==="
}

stage_inspection() {
  step "Inspection / Pre-build"
  elixir --version || return $?
  test -f README.md || return $?

  step "Inspection / Build tools"
  mix local.hex --force || return $?
  mix local.rebar --force || return $?
  mix deps.get || return $?
}

stage_preparation() {
  step "Preparation"
  mix clean || return $?
  mix validate || return $?
}

stage_build() {
  step "Build / Format check"
  mix format --check-formatted || return $?

  step "Build / Lint"
  mix credo --strict || return $?

  step "Build / Resources (profile: ci)"
  mix resources --profile ci || return $?

  step "Build / Compile"
  mix compile --warnings-as-errors || return $?

  step "Build / Tooling self-tests (§7.7)"
  mix tooling_test || return $?

  step "Build / Unit tests"
  mix test.unit || return $?

  step "Build / Pre-integration-test"
  mix pre_integration_test || return $?

  step "Build / Integration tests"
  integration_status=0
  mix test.integration || integration_status=$?

  # Guaranteed cleanup even if integration tests failed, matching
  # Jenkinsfile's Build-stage `post { always { ... } }`.
  step "Build / Post-integration-test (always)"
  mix post_integration_test

  return "$integration_status"
}

stage_e2e() {
  step "E2E / Pre-e2e-test"
  mix pre_e2e_test || return $?

  step "E2E / e2e tests"
  e2e_status=0
  mix test.e2e || e2e_status=$?

  step "E2E / Post-e2e-test (always)"
  mix post_e2e_test

  return "$e2e_status"
}

stage_quality() {
  step "Quality / Mutation tests"
  echo 'Put here mutation tests once wired in (neither JS nor Python side has this either, though both PoCs used Muzak - see report.md)'

  step "Quality / Coverage"
  mix coverage || return $?

  step "Quality / Security"
  mix security || return $?

  step "Quality / Verify"
  mix verify || return $?

  step "Quality / Reporting site"
  mix sbom || return $?
  mix site || return $?
}

stage_system_acceptance() {
  step "System tests"
  echo 'Put here system tests'

  step "Acceptance tests"
  echo 'Put here acceptance tests'
}

stage_package() {
  step "Package"
  mix package || return $?
  mix sign || return $?
}

# $1: "Release" or "Snapshot" (label only, matches the Jenkinsfile stage
# names) - both run the same commands, BRANCH_NAME (set by the caller) is
# what makes Mix.Tasks.Publish resolve the right branch/version behavior.
stage_publish() {
  step "Publish / $1"
  echo "Software $1 publish steps"
  mix install_local || return $?
  mix publish || return $?
}

# $1: dev | test | prelive | live - matches Jenkinsfile's Deploy/<target>
# parallel stages exactly, including the DEPLOY_TARGET env var name.
stage_deploy() {
  step "Deploy / $1"
  DEPLOY_TARGET="$1" mix deploy || return $?
}

stage_tag() {
  step "Tag"
  echo 'Put here tagging steps'
}

# $1: pipeline exit status (0 = success)
notify() {
  step "post always"
  echo "Always"

  if [ "$1" -eq 0 ]; then
    echo "Build SUCCESSFUL - put real notification steps here (e.g. an email/Slack action), same role as Jenkinsfile's emailext success post step."
  else
    echo "Build FAILED - put real notification steps here (e.g. an email/Slack action), same role as Jenkinsfile's emailext failure post step."
  fi
}
