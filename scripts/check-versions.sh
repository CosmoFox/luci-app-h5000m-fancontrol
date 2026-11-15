#!/bin/sh
# Keep the Makefile version and the changelog top in sync: the top
# "## X.Y.Z" heading of CHANGELOG.md must equal PKG_VERSION, so a
# version bump commit must update the changelog too.
set -eu

cd "$(dirname "$0")/.."

version="$(sed -n 's/^PKG_VERSION:=//p' Makefile | tr -d '\r' | head -n 1)"
case "$version" in
	''|*[!0-9.]*)
		echo "check-versions: cannot parse PKG_VERSION from Makefile" >&2
		exit 1
		;;
esac

head="$(grep -m1 '^## ' CHANGELOG.md | sed 's/^## //')"
if [ "$head" != "$version" ]; then
	echo "check-versions: CHANGELOG.md top entry is '${head}', expected '${version}'" >&2
	exit 1
fi

echo "check-versions: PKG_VERSION ${version} matches CHANGELOG.md"
