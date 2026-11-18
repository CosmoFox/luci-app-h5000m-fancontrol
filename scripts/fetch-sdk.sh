#!/usr/bin/env bash
set -euo pipefail

# Single source of truth for the OpenWrt SDK used by CI and release builds.
# Subcommands:
#   version  - print the OpenWrt release version of the SDK
#   archive  - print the SDK archive file name from sha256sums
#   key      - print the short checksum used as the Actions cache key
#   download - ensure the verified SDK archive lives in the cache directory
#              (SDK_CACHE_DIR, default ${RUNNER_TEMP:-/tmp}/h5000m-fan-sdk);
#              prints the archive file name

sdk_version=25.12.6
base_url="https://downloads.openwrt.org/releases/${sdk_version}/targets/mediatek/filogic"
cache_dir="${SDK_CACHE_DIR:-${RUNNER_TEMP:-/tmp}/h5000m-fan-sdk}"

fetch_sums() {
	curl -fsSLO --output-dir "$1" "${base_url}/sha256sums"
}

resolve_archive() {
	awk '/openwrt-sdk-.*Linux-x86_64\.tar\.zst$/ { print $2; exit }' "$1" | sed 's/^\*//'
}

resolve_key() {
	awk -v a="$2" '$0 ~ "[ *]"a"$" { print $1; exit }' "$1" | cut -c1-16
}

case "${1:-}" in
	version)
		printf '%s\n' "${sdk_version}"
		;;
	archive | key)
		d="$(mktemp -d)"
		trap 'rm -rf "${d}"' EXIT
		fetch_sums "${d}"
		archive="$(resolve_archive "${d}/sha256sums")"
		test -n "${archive}"
		if [ "$1" = key ]; then
			resolve_key "${d}/sha256sums" "${archive}"
		else
			printf '%s\n' "${archive}"
		fi
		;;
	download)
		mkdir -p "${cache_dir}"
		fetch_sums "${cache_dir}"
		archive="$(resolve_archive "${cache_dir}/sha256sums")"
		test -n "${archive}"
		if ! ( test -s "${cache_dir}/${archive}" \
			&& grep "[ *]${archive}$" "${cache_dir}/sha256sums" | sha256sum -c - >/dev/null 2>&1 ); then
			curl -fL --retry 5 "${base_url}/${archive}" -o "${cache_dir}/${archive}"
		fi
		grep "[ *]${archive}$" "${cache_dir}/sha256sums" | sha256sum -c - >&2
		printf '%s\n' "${archive}"
		;;
	*)
		printf 'usage: %s {version|archive|key|download}\n' "${0##*/}" >&2
		exit 2
		;;
esac
