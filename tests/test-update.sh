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

# norm_lang: case/underscore folding, Chinese aliases, auto/empty -> empty
expect_eq "$(norm_lang RU)" "ru" 'norm_lang upper'
expect_eq "$(norm_lang ru)" "ru" 'norm_lang plain'
expect_eq "$(norm_lang zh_CN)" "zh-cn" 'norm_lang underscore'
expect_eq "$(norm_lang zh-CN)" "zh-cn" 'norm_lang dash case'
expect_eq "$(norm_lang zh_Hans)" "zh-cn" 'norm_lang zh-Hans alias'
expect_eq "$(norm_lang zh-Hant)" "zh-tw" 'norm_lang zh-Hant alias'
expect_eq "$(norm_lang pt-br)" "pt-br" 'norm_lang region kept'
expect_eq "$(norm_lang auto)" "" 'norm_lang auto'
expect_eq "$(norm_lang "")" "" 'norm_lang empty'

# i18n_lang_from_name: apk/ipk spellings, multi-part codes, others -> empty
expect_eq "$(i18n_lang_from_name luci-i18n-h5000m-fancontrol-ru-2.3.1-r1.apk)" "ru" 'i18n lang apk'
expect_eq "$(i18n_lang_from_name luci-i18n-h5000m-fancontrol-zh-cn-2.3.1-r1.apk)" "zh-cn" 'i18n lang apk multi'
expect_eq "$(i18n_lang_from_name luci-i18n-h5000m-fancontrol-ru_2.3.1-r1_all.ipk)" "ru" 'i18n lang ipk'
expect_eq "$(i18n_lang_from_name luci-i18n-h5000m-fancontrol-zh-cn_2.3.1-r1_all.ipk)" "zh-cn" 'i18n lang ipk multi'
expect_eq "$(i18n_lang_from_name luci-app-h5000m-fancontrol-2.3.1-r1.apk)" "" 'i18n lang app asset'
expect_eq "$(i18n_lang_from_name nonsense.apk)" "" 'i18n lang garbage'

# collect_langs: normalize, drop empties, dedupe (case/underscore variants
# fold to the same code; region subtags stay distinct - the package
# resolution dedupes them later, e.g. ru + ru-ru -> one ru package)
expect_eq "$(collect_langs ru zh-cn)" "ru zh-cn" 'collect_langs two'
expect_eq "$(collect_langs RU ru zh_CN)" "ru zh-cn" 'collect_langs dedupe'
expect_eq "$(collect_langs ru-RU ru)" "ru-ru ru" 'collect_langs region distinct'
expect_eq "$(collect_langs "" auto ru)" "ru" 'collect_langs skips empty/auto'
expect_eq "$(collect_langs)" "" 'collect_langs none'
expect_eq "$(collect_langs zz)" "zz" 'collect_langs unknown kept'

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

# b64 falls back to hexdump+awk when neither base64 nor openssl exists
# (minimal OpenWrt images) - covered here via bsdextrautils in CI.
mkdir -p "${TDIR}/hexbin"
_hexdump_path=$(command -v hexdump 2>/dev/null || true)
_awk_path=$(command -v awk 2>/dev/null || true)
if [ -n "${_hexdump_path}" ] && [ -n "${_awk_path}" ]; then
	ln -sf "${_hexdump_path}" "${TDIR}/hexbin/hexdump"
	ln -sf "${_awk_path}" "${TDIR}/hexbin/awk"
	_out=$(PATH="${TDIR}/hexbin" b64 'hello')
	expect_eq "${_out}" "aGVsbG8=" 'b64 hexdump fallback'
fi

# CLI smoke: unknown command exits non-zero with the usage error
if sh "${UPD}" bogus > "${TDIR}/bogus.out" 2>&1; then
	tfail 'bogus command should exit non-zero'
fi
grep -q 'usage: update.sh' "${TDIR}/bogus.out" || tfail 'bogus: usage message missing'

echo "test-update: all tests passed"
