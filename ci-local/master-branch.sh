#!/bin/sh
# Emulates ../Jenkinsfile's behavior for a `master` build.
#
# Branch-gated stages that actually run on master, per the Jenkinsfile's
# `when` conditions (Publish/Release: `branch 'master'`; Deploy/live:
# `env.MASTER_TO_LIVE == 'DEPLOY' && env.BRANCH_NAME == 'master'`; Tag:
# `branch 'master' && env.MASTER_TO_LIVE == 'DEPLOY'`): Publish/Release,
# Deploy/live, Tag. master does NOT match Deploy/dev, Deploy/test, or
# Deploy/prelive's `when` conditions (all three require a `devel*` or
# `release*` branch name), so none of those run here - same as Jenkins.
#
# Nothing here sets HEX_API_KEY, so `mix publish` always stays a local
# `mix hex.build`-only dry-run, same as every other case script and the
# Jenkinsfile.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

BRANCH_NAME="${BRANCH_NAME:-master}"
export BRANCH_NAME

echo "Emulating Jenkins CI for branch: $BRANCH_NAME (master case)"

status=0
stage_inspection &&
  stage_preparation &&
  stage_build &&
  stage_e2e &&
  stage_quality &&
  stage_system_acceptance &&
  stage_package || status=$?

if [ "$status" -eq 0 ]; then
  stage_publish "Release" || status=$?
fi

if [ "$status" -eq 0 ]; then
  stage_deploy "live" || status=$?
fi

if [ "$status" -eq 0 ]; then
  stage_tag || status=$?
fi

notify "$status"
exit "$status"
