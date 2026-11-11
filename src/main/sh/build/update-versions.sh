#!/bin/sh
#
# Bump the version of this project in one step, the way the configuration projects'
# src/main/sh/build/update-versions.sh does. Run it from the project root:
#
#   src/main/sh/build/update-versions.sh 0.2.0 'what changed, one line'
#
# It changes @version in mix.exs, which rpm/Makefile passes to every rpm/*.spec as the RPM
# version. The second argument is optional: with it every spec also gets a %changelog entry
# of today with that one line, without it only the number changes and the entries are
# written by hand. The apps keep their own versions, their Hex package versions.

set -e

NEW_VERSION="${1:?Usage: update-versions.sh <new-version> [changelog line]  (e.g. 0.2.0)}"
CHANGELOG_LINE="${2:-}"

if [ ! -f mix.exs ] || [ ! -f rpm/Makefile ]; then
    printf 'mix.exs or rpm/Makefile not found: run this from the project root\n' >&2
    exit 1
fi

case "${NEW_VERSION}" in
    *[!0-9.]*|.*|*.|*..*) printf 'not a version: %s\n' "${NEW_VERSION}" >&2; exit 1 ;;
esac

OLD_VERSION=$(sed -n 's/^ *@version "\([0-9.]*\)".*/\1/p' mix.exs)

if [ -z "${OLD_VERSION}" ]; then
    printf 'no @version line in mix.exs\n' >&2
    exit 1
fi

if [ "${OLD_VERSION}" = "${NEW_VERSION}" ]; then
    printf 'already at %s\n' "${NEW_VERSION}" >&2
    exit 1
fi

sed -i "s/^\( *@version \"\)[0-9][0-9.]*\"/\1${NEW_VERSION}\"/" mix.exs

if [ -n "${CHANGELOG_LINE}" ]; then
    ENTRY=$(mktemp)
    {
        printf '* %s Imre Tabur <imre.tabur@mail.ee> - %s-1\n' \
            "$(LC_ALL=C date '+%a %b %d %Y')" "${NEW_VERSION}"
        printf -- '- %s\n' "${CHANGELOG_LINE}"
        printf '\n'
    } > "${ENTRY}"
    for SPEC in rpm/*.spec; do
        sed -i "/^%changelog\$/r ${ENTRY}" "${SPEC}"
    done
    rm -f "${ENTRY}"
fi

printf '%s -> %s\n' "${OLD_VERSION}" "${NEW_VERSION}"
grep -H '^ *@version' mix.exs

if command -v rpmspec >/dev/null 2>&1; then
    for SPEC in rpm/*.spec; do
        rpmspec -D "smi_version ${NEW_VERSION}" -D 'smi_release 1' -q "${SPEC}" >/dev/null ||
            printf 'BROKEN %s\n' "${SPEC}"
    done
fi
