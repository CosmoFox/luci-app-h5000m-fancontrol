#!/bin/sh
# Keep the Makefile version and the changelog tops in sync: the top
# "## X.Y.Z" heading of every CHANGELOG*.md must equal PKG_VERSION, so a
# version bump commit must update the changelogs too.
set -eu

cd "$(dirname "$0")/.."

version="$(sed -n 's/^PKG_VERSION:=//p' Makefile | tr -d '\r' | head -n 1)"
case "$version" in
	''|*[!0-9.]*)
		echo "check-versions: cannot parse PKG_VERSION from Makefile" >&2
		exit 1
		;;
esac

status=0
for f in CHANGELOG.md CHANGELOG.ru.md CHANGELOG.zh-CN.md; do
	head="$(grep -m1 '^## ' "$f" | sed 's/^## //')"
	if [ "$head" != "$version" ]; then
		echo "check-versions: $f top entry is '${head}', expected '${version}'" >&2
		status=1
	fi
done

if [ "$status" -eq 0 ]; then
	echo "check-versions: PKG_VERSION ${version} matches all changelogs"
fi
exit "$status"
