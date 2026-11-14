#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
UPD="${ROOT}/root/usr/share/h5000m-fancontrol/update.sh"
# Sourcing update.sh overwrites TMP/STATUS/LOG with its own paths, so the
# scratch dir lives in its own variable and the trap expands it right here.
TDIR="$(mktemp -d)"
cleanup() { rm -rf "$TDIR"; }
trap cleanup EXIT INT TERM

tfail() {
	echo "FAIL: $1" >&2
	exit 1
}

expect_eq() { # <actual> <expected> <label>
	[ "$1" = "$2" ] || tfail "$3: expected [$2], got [$1]"
}

# The script dispatches on $1 at load time; source it with the guard set so
# only the helpers get defined (jsonfilter/wget are not needed for these).
H5FAN_UPDATE_SOURCED=1
# shellcheck source=../root/usr/share/h5000m-fancontrol/update.sh
. "${UPD}"
unset H5FAN_UPDATE_SOURCED

# Route the script's scratch files into the test tmpdir.
TMP="${TDIR}"
STATUS="${TDIR}/status.json"
LOG="${TDIR}/update.log"
STEPF="${TDIR}/update.step"

# version_gt
expect_eq "$(version_gt 2.4.0 2.3.1)" 1 'version_gt newer'
expect_eq "$(version_gt 2.3.1 2.3.1)" 0 'version_gt equal'
expect_eq "$(version_gt 2.3.1 2.4.0)" 0 'version_gt older'
expect_eq "$(version_gt 2.10.0 2.9.9)" 1 'version_gt numeric segments'
expect_eq "$(version_gt 2.3 2.3.1)" 0 'version_gt missing segment'
expect_eq "$(version_gt 2.3.1 2.3)" 1 'version_gt extra segment'

# ver_from_name (apk '-', ipk '_' separators and the ipk _all suffix)
expect_eq "$(ver_from_name luci-app-h5000m-fancontrol-2.3.1-r1.apk)" "2.3.1" 'ver apk'
expect_eq "$(ver_from_name luci-app-h5000m-fancontrol_2.3.1-r1_all.ipk)" "2.3.1" 'ver ipk'
expect_eq "$(ver_from_name luci-i18n-h5000m-fancontrol-ru-2.3.1-r1.apk)" "2.3.1" 'ver i18n apk'
expect_eq "$(ver_from_name luci-i18n-h5000m-fancontrol-ru_2.3.1-r1_all.ipk)" "2.3.1" 'ver i18n ipk'
expect_eq "$(ver_from_name nonsense.apk)" "" 'ver garbage'

# json_esc: quotes and backslashes escaped, CR dropped, LF/TAB folded to spaces
expect_eq "$(json_esc 'a"b\c')" 'a\"b\\c' 'json_esc quote/backslash'
expect_eq "$(json_esc "$(printf 'a\nb\tc\rd')")" 'a b cd' 'json_esc control chars'

# b64 round-trips through the system decoder (ASCII and UTF-8)
expect_eq "$(b64 'hello')" "aGVsbG8=" 'b64 hello'
expect_eq "$(b64 'hello' | base64 -d 2>/dev/null)" "hello" 'b64 roundtrip ascii'
expect_eq "$(b64 'привет' | base64 -d 2>/dev/null)" "привет" 'b64 roundtrip utf8'

# fail(): JSON shape with escaped detail from the log tail (4 lines max)
PM=""
TARGET="v9.9.9"
printf 'line1\nline2 "quoted" \\ slash\nline3\nline4\nline5\n' > "${TDIR}/pm.log"
LOG="${TDIR}/pm.log"
_out=$(fail no_space "luci-app-h5000m-fancontrol")
echo "${_out}" | grep -q '"error":"no_space"' || tfail "fail: error field missing: ${_out}"
echo "${_out}" | grep -q '"target":"v9.9.9"' || tfail "fail: target field missing: ${_out}"
echo "${_out}" | grep -q 'line5' || tfail "fail: last log line missing: ${_out}"
echo "${_out}" | grep -q 'line1' && tfail "fail: log tail should keep only 4 lines: ${_out}"
echo "${_out}" | grep -q 'line2 \\"quoted\\"' || tfail "fail: detail not escaped: ${_out}"

# apk_world_blockers: world-required missing packages are listed, others ignored
cat > "${TDIR}/apk-world.log" <<'EOF'
ERROR: unable to select packages:
  foo (no such package):
    required by: world[foo]
  bar-1.0-r0 (no such package):
    required by: world[bar]
  baz (no such package):
    required by: luci-app-5gmodem-3.9.44-r1[baz]
EOF
LOG="${TDIR}/apk-world.log"
expect_eq "$(apk_world_blockers)" "bar-1.0-r0 foo" 'apk_world_blockers names'
printf 'OK: everything up to date\n' > "${TDIR}/apk-clean.log"
LOG="${TDIR}/apk-clean.log"
expect_eq "$(apk_world_blockers)" "" 'apk_world_blockers clean log'

# progress(): byte counters, target and step land in the status snapshot
TARGET="v2.4.0"
progress download 1024 20480
grep -q '"stage":"download"' "${STATUS}" || tfail "progress: stage missing"
grep -q '"done":1024' "${STATUS}" || tfail "progress: done missing"
grep -q '"total":20480' "${STATUS}" || tfail "progress: total missing"
grep -q '"target":"v2.4.0"' "${STATUS}" || tfail "progress: target missing"

# CLI smoke: version works without a package manager and prints valid JSON
_out=$(sh "${UPD}" version)
echo "${_out}" | grep -q '"installed":""' || tfail "version: unexpected output: ${_out}"
echo "${_out}" | grep -q '"pm":""' || tfail "version: pm field missing: ${_out}"

# CLI smoke: unknown command exits non-zero with the usage error
if sh "${UPD}" bogus > "${TDIR}/bogus.out" 2>&1; then
	tfail 'bogus command should exit non-zero'
fi
grep -q 'usage: update.sh' "${TDIR}/bogus.out" || tfail 'bogus: usage message missing'

echo "test-update: all tests passed"
