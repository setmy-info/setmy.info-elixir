#!/bin/sh
# Emulates ../Jenkinsfile's behavior for a `release*` build (e.g.
# `release-1.0.0`).
#
# Branch-gated stages that actually run, per the Jenkinsfile's `when`
# conditions (all keyed off `env.BRANCH_NAME.startsWith('release')`):
# Deploy/dev, Deploy/test, Deploy/prelive.
#
# Notably absent, and this is a faithful reproduction of the Jenkinsfile's
# actual logic, not a bug in this emulation: release* does NOT publish.
# Publish/Release requires `branch 'master'` exactly and Publish/Snapshot
# requires `startsWith('devel')` - a `release*` branch name matches
# neither `when` condition, so the Publish stage produces nothing on
# release* in real Jenkins either (same quirk documented on the JS/Python
# sides). Deploy/live and Tag are both `master`-only too, so neither runs
# here.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

BRANCH_NAME="${BRANCH_NAME:-release-1.0.0}"
export BRANCH_NAME

echo "Emulating Jenkins CI for branch: $BRANCH_NAME (release* case)"

status=0
stage_inspection &&
  stage_preparation &&
  stage_build &&
  stage_e2e &&
  stage_quality &&
  stage_system_acceptance &&
  stage_package || status=$?

if [ "$status" -eq 0 ]; then
  stage_deploy "dev" || status=$?
fi

if [ "$status" -eq 0 ]; then
  stage_deploy "test" || status=$?
fi

if [ "$status" -eq 0 ]; then
  stage_deploy "prelive" || status=$?
fi

notify "$status"
exit "$status"
