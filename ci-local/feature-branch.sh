#!/bin/sh
# Emulates ../Jenkinsfile's behavior for a feature/any-other branch - i.e.
# any branch name that is not `master`, does not start with `devel`, and
# does not start with `release`.
#
# None of the Publish/Deploy/Tag `when` conditions match a branch name like
# this, so none of those stages run - a developer gets full Inspection
# through Package build/lint/test/quality feedback and nothing else.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

BRANCH_NAME="${BRANCH_NAME:-feature/local-emulation}"
export BRANCH_NAME

echo "Emulating Jenkins CI for branch: $BRANCH_NAME (feature/other case)"

status=0
stage_inspection &&
  stage_preparation &&
  stage_build &&
  stage_e2e &&
  stage_quality &&
  stage_system_acceptance &&
  stage_package || status=$?

notify "$status"
exit "$status"
