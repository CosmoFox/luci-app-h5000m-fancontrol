#!/usr/bin/env bash
set -euo pipefail

tag="${1:-}"
if [[ ! "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]]; then
	echo "usage: $(basename "${BASH_SOURCE[0]}") vMAJOR.MINOR.PATCH | vMAJOR.MINOR.PATCH-beta.N" >&2
	echo "  stable tags must be cut from 'main', -beta tags from 'beta'" >&2
	exit 1
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_dir}"

base="${tag#v}"; base="${base%%-*}"
pkg_version="$(sed -n 's/^PKG_VERSION:=//p' Makefile | tr -d '\r')"
if [ "${base}" != "${pkg_version}" ]; then
	echo "error: tag base '${base}' does not match Makefile PKG_VERSION '${pkg_version}'" >&2
	exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
	echo "error: working tree is not clean" >&2
	exit 1
fi

if [[ "${tag}" == *-beta.* ]]; then
	branch=beta
else
	branch=main
fi
current="$(git rev-parse --abbrev-ref HEAD)"
if [ "${current}" != "${branch}" ]; then
	echo "error: ${tag} must be tagged from '${branch}' (current branch: ${current})" >&2
	exit 1
fi

git fetch --no-tags origin "refs/heads/${branch}:refs/remotes/origin/${branch}"
if [ "$(git rev-parse HEAD)" != "$(git rev-parse "refs/remotes/origin/${branch}")" ]; then
	echo "error: HEAD differs from origin/${branch}; push your commits first" >&2
	exit 1
fi

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null \
	|| git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
	echo "error: tag ${tag} already exists" >&2
	exit 1
fi

git tag -a "${tag}" -m "Release ${tag}"
git push origin "refs/tags/${tag}"
if [ "${branch}" = main ]; then
	echo "pushed ${tag} from ${branch}; GitHub Actions will publish the release"
else
	echo "pushed ${tag} from ${branch}; GitHub Actions will publish the prerelease"
fi
