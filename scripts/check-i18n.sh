#!/bin/sh
# Every _('...') msgid used by the LuCI view must exist in every shipped
# translation, so a new UI string cannot be forgotten in the .po files.
set -eu

cd "$(dirname "$0")/.."

JS="htdocs/luci-static/resources/view/h5000m/fancontrol.js"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

# Extract '_('...')' literals (handling \' and \\ escapes) in one awk pass.
awk -v q="'" '
	BEGIN { RS = "^$" }
	{
		s = $0
		while ((p = index(s, "_(" q)) > 0) {
			rest = substr(s, p + 3)
			out = ""
			i = 1
			n = length(rest)
			while (i <= n) {
				c = substr(rest, i, 1)
				if (c == "\\") {
					out = out substr(rest, i + 1, 1)
					i += 2
					continue
				}
				if (c == q) break
				out = out c
				i++
			}
			print out
			s = substr(rest, i + 1)
		}
	}
' "$JS" | LC_ALL=C sort -u > "${TMP}/msgids"

total="$(wc -l < "${TMP}/msgids" | tr -d ' ')"
[ "${total}" -gt 0 ] || { echo "check-i18n: no msgids extracted from $JS" >&2; exit 1; }

status=0
for po in po/*/*.po; do
	while IFS= read -r msgid; do
		# po format escapes backslashes and double quotes in msgids.
		esc="$(printf '%s' "$msgid" | sed 's/\\/\\\\/g; s/"/\\"/g')"
		if ! grep -q "^msgid \"${esc}\"$" "$po"; then
			echo "check-i18n: missing in ${po}: ${msgid}" >&2
			status=1
		fi
	done < "${TMP}/msgids"
done

if [ "$status" -eq 0 ]; then
	echo "check-i18n: all ${total} msgids present in every translation"
fi
exit "$status"
