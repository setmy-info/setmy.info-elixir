#!/bin/sh
# Picks the right case script for a branch name, using exactly the same
# matching rules as ../Jenkinsfile's `when` conditions (branch 'master' /
# startsWith('devel') / startsWith('release') / anything else), then runs
# it.
#
# Usage:
#   ci-local/run.sh                 # uses the current git branch
#   ci-local/run.sh some-branch-name

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

branch="${1:-}"

if [ -z "$branch" ]; then
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

if [ -z "$branch" ]; then
  echo "Could not determine a branch name (not a git checkout?) - pass one explicitly: ci-local/run.sh <branch-name>" >&2
  exit 1
fi

case "$branch" in
  master)
    case_script="$SCRIPT_DIR/master-branch.sh"
    ;;
  devel*)
    case_script="$SCRIPT_DIR/devel-branch.sh"
    ;;
  release*)
    case_script="$SCRIPT_DIR/release-branch.sh"
    ;;
  *)
    case_script="$SCRIPT_DIR/feature-branch.sh"
    ;;
esac

echo "Branch \"$branch\" -> $(basename "$case_script")"
BRANCH_NAME="$branch" exec "$case_script"
