#!/bin/sh
# Emulates ../Jenkinsfile's behavior for a `devel*` build (e.g. `develop`,
# `devel-feature-x`).
#
# Branch-gated stages that actually run, per the Jenkinsfile's `when`
# conditions (all keyed off `env.BRANCH_NAME.startsWith('devel')`):
# Publish/Snapshot, Deploy/dev, Deploy/test. Deploy/prelive and Deploy/live
# both require a `release*`/`master` branch name respectively, so neither
# runs here, and there's no Tag stage for devel* at all (Tag is
# `branch 'master'`-gated only) - same as Jenkins.
#
# Nothing here sets HEX_API_KEY, so `mix publish` always stays a local
# `mix hex.build`-only dry-run, same as every other case script and the
# Jenkinsfile.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

BRANCH_NAME="${BRANCH_NAME:-devel}"
export BRANCH_NAME

echo "Emulating Jenkins CI for branch: $BRANCH_NAME (devel* case)"

status=0
stage_inspection &&
  stage_preparation &&
  stage_build &&
  stage_e2e &&
  stage_quality &&
  stage_system_acceptance &&
  stage_package || status=$?

if [ "$status" -eq 0 ]; then
  stage_publish "Snapshot" || status=$?
fi

if [ "$status" -eq 0 ]; then
  stage_deploy "dev" || status=$?
fi

if [ "$status" -eq 0 ]; then
  stage_deploy "test" || status=$?
fi

notify "$status"
exit "$status"
