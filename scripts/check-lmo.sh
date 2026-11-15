#!/bin/sh
# The .lmo catalogs embedded in the main package (root/usr/lib/lua/luci/i18n)
# must always match the .po sources. Regenerate each catalog with
# scripts/po2lmo.py and byte-compare; also flag orphan catalogs without a
# .po source. Run after editing any translation; CI runs this too.
set -eu

cd "$(dirname "$0")/.."

PY=""
for c in python3 python; do
	if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then
		PY="$c"
		break
	fi
done
[ -n "$PY" ] || { echo "check-lmo: no working python interpreter found" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
status=0

for po in po/*/*.po; do
	lang=${po#po/}
	lang=${lang%%/*}
	[ "$lang" = "templates" ] && continue
	case "$lang" in
	zh_Hans) code=zh-cn ;;
	*) code=$lang ;;
	esac
	lmo="root/usr/lib/lua/luci/i18n/h5000m-fancontrol.$code.lmo"
	if [ ! -f "$lmo" ]; then
		echo "check-lmo: missing embedded catalog $lmo (source $po)" >&2
		status=1
		continue
	fi
	"$PY" scripts/po2lmo.py "$po" "$TMP/$code.lmo" >/dev/null
	if ! cmp -s "$TMP/$code.lmo" "$lmo"; then
		echo "check-lmo: stale catalog $lmo - regenerate with: $PY scripts/po2lmo.py $po $lmo" >&2
		status=1
	fi
done

for lmo in root/usr/lib/lua/luci/i18n/*.lmo; do
	code=${lmo##*h5000m-fancontrol.}
	code=${code%.lmo}
	case "$code" in
	zh-cn) lang=zh_Hans ;;
	*) lang=$code ;;
	esac
	if [ ! -f "po/$lang/h5000m-fancontrol.po" ]; then
		echo "check-lmo: orphan catalog $lmo (no po/$lang source)" >&2
		status=1
	fi
done

if [ "$status" -eq 0 ]; then
	echo "check-lmo: all embedded catalogs match the .po sources"
fi
exit "$status"
