#!/bin/sh
#
# Shared helpers for the H5000M fan controller. Sourced by
# /usr/sbin/h5000m-fancontrol (see H5000M_FAN_LIB there) and by the unit
# tests in tests/. Everything in this file must stay POSIX-sh compatible and
# work under BusyBox ash; keep it free of side effects - functions only.

is_uint() {
	case "$1" in
		''|*[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

clamp() {
	local value="$1" min="$2" max="$3"
	[ "$value" -lt "$min" ] && value="$min"
	[ "$value" -gt "$max" ] && value="$max"
	echo "$value"
}

read_temp_c() {
	local value=""
	if [ -r "$1" ]; then
		IFS= read -r value < "$1" 2>/dev/null || value="${value:-}"
	fi
	case "$value" in ''|*[!0-9-]*) return 1 ;; esac
	if [ "$value" -gt 1000 ] 2>/dev/null || [ "$value" -lt -1000 ] 2>/dev/null; then
		value=$((value / 1000))
	fi
	[ "$value" -ge -40 ] 2>/dev/null && [ "$value" -le 150 ] 2>/dev/null || return 1
	echo "$value"
}

fresh_enough() { # <file> [snapshot_age]
	local now mtime
	is_uint "${MT5700M_TEMP_MAX_AGE:-300}" || return 1
	now="$(date +%s 2>/dev/null)"
	is_uint "$now" || return 1
	mtime="$(date -r "$1" +%s 2>/dev/null)"
	is_uint "$mtime" || return 1
	[ $((now - mtime)) -ge 0 ] && [ $((now - mtime)) -le "${MT5700M_TEMP_MAX_AGE:-300}" ] || return 1
	[ -n "${2:-}" ] || return 0
	is_uint "$2" && [ "$2" -le "${MT5700M_TEMP_MAX_AGE:-300}" ]
}

calc_curve_pwm() {
	local temp="$1" curve="$2" old_ifs point t p prev_t prev_p result
	old_ifs="$IFS"; IFS=','
	for point in $curve; do
		t="${point%%:*}"; p="${point#*:}"
		is_uint "$t" && is_uint "$p" && [ "$t" -le 150 ] && [ "$p" -le 100 ] || { IFS="$old_ifs"; return 1; }
		if [ -n "${prev_t:-}" ] && [ "$t" -le "$prev_t" ]; then IFS="$old_ifs"; return 1; fi
		if [ "$temp" -le "$t" ]; then
			if [ -z "${prev_t:-}" ]; then
				result="$p"
			else
				result=$((prev_p + (temp - prev_t) * (p - prev_p) / (t - prev_t)))
			fi
			IFS="$old_ifs"
			echo $((result * 255 / 100))
			return 0
		fi
		prev_t="$t"; prev_p="$p"
	done
	IFS="$old_ifs"
	[ -n "${prev_p:-}" ] || return 1
	echo $((prev_p * 255 / 100))
}

# Parse the MT5700M module temperature cache ("temperature=...", "updated=...")
# in a single awk pass. Prints "<rounded temp>|<updated>" when both fields are
# present and sane; nothing otherwise.
parse_mt5700m_cache() {
	awk -F= '
		$1 == "updated" && $2 ~ /^[0-9]+$/ { upd = $2; next }
		$1 == "temperature" && $2 ~ /^-?[0-9]+([.][0-9]+)?$/ {
			v = $2 + 0
			if (v >= -40 && v <= 150)
				temp = sprintf("%d", (v < 0 ? v - 0.5 : v + 0.5))
		}
		END { if (temp != "" && upd != "") printf "%s|%s\n", temp, upd }
	' "$1" 2>/dev/null
}

# Extract the modem name, snapshot age and modem temperature from one 5gmodem
# metrics JSON snapshot in a single awk pass (replaces the per-key sed/grep
# pipelines). Prints "<modem>|<age>|<mtemp>"; missing keys come out empty.
parse_5gmodem_metrics() {
	awk '
		function grab_str(key, s,   pos, rest) {
			pos = index(s, "\"" key "\"")
			if (!pos) return ""
			rest = substr(s, pos + length(key) + 2)
			sub(/^[ \t]*:[ \t]*"/, "", rest)
			pos = index(rest, "\"")
			if (!pos) return ""
			return substr(rest, 1, pos - 1)
		}
		function grab_num(key, s,   pos, rest, i, c, out) {
			pos = index(s, "\"" key "\"")
			if (!pos) return ""
			rest = substr(s, pos + length(key) + 2)
			sub(/^[ \t]*:[ \t]*"?/, "", rest)
			out = ""
			for (i = 1; i <= length(rest); i++) {
				c = substr(rest, i, 1)
				if (c !~ /[0-9]/) break
				out = out c
			}
			return out
		}
		{ line = (line == "" ? $0 : line " " $0) }
		END { printf "%s|%s|%s\n", grab_str("modem", line), grab_num("age", line), grab_str("mtemp", line) }
	' "$1" 2>/dev/null
}
