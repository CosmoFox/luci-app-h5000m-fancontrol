#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LIB="${ROOT}/root/usr/share/h5000m-fancontrol/lib.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

# shellcheck source=../root/usr/share/h5000m-fancontrol/lib.sh
. "${LIB}"

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

expect_eq() { # <actual> <expected> <label>
	[ "$1" = "$2" ] || fail "$3: expected [$2], got [$1]"
}

# is_uint
is_uint 0 || fail 'is_uint 0'
is_uint 12345 || fail 'is_uint 12345'
if is_uint ''; then fail 'is_uint empty'; fi
if is_uint 12a; then fail 'is_uint 12a'; fi
if is_uint -1; then fail 'is_uint -1'; fi
if is_uint ' 1'; then fail 'is_uint leading space'; fi

# clamp
expect_eq "$(clamp 5 0 10)" 5 'clamp middle'
expect_eq "$(clamp -3 0 10)" 0 'clamp low'
expect_eq "$(clamp 42 0 10)" 10 'clamp high'

# calc_curve_pwm: points below the first return the first percentage, between
# points it interpolates linearly, above the last it holds the last value.
CURVE='20:0,35:0,40:50,55:60,70:75,85:90,95:100'
expect_eq "$(calc_curve_pwm 10 "$CURVE")" 0 'curve below first point'
expect_eq "$(calc_curve_pwm 20 "$CURVE")" 0 'curve at first point'
expect_eq "$(calc_curve_pwm 37 "$CURVE")" 51 'curve interpolation 37 -> 20%'
expect_eq "$(calc_curve_pwm 40 "$CURVE")" 127 'curve at 40 -> 50%'
expect_eq "$(calc_curve_pwm 47 "$CURVE")" 137 'curve interpolation 47'
expect_eq "$(calc_curve_pwm 95 "$CURVE")" 255 'curve at last point'
expect_eq "$(calc_curve_pwm 110 "$CURVE")" 255 'curve above last point'
expect_eq "$(calc_curve_pwm 30 '40:50')" 127 'single point curve'
if calc_curve_pwm 45 '40:50,30:60' >/dev/null 2>&1; then fail 'curve decreasing temps accepted'; fi
if calc_curve_pwm 40 '40:150' >/dev/null 2>&1; then fail 'curve percent > 100 accepted'; fi
if calc_curve_pwm 40 'abc:def' >/dev/null 2>&1; then fail 'curve garbage accepted'; fi
if calc_curve_pwm 40 '' >/dev/null 2>&1; then fail 'empty curve accepted'; fi

# read_temp_c: kernel readings are millidegrees, plain degrees pass through,
# out-of-range and non-numeric values are rejected.
printf '45678\n' > "${TMP}/t1"; expect_eq "$(read_temp_c "${TMP}/t1")" 45 'millidegrees conversion'
printf '45\n' > "${TMP}/t2"; expect_eq "$(read_temp_c "${TMP}/t2")" 45 'plain degrees'
printf -- '-5000\n' > "${TMP}/t3"; expect_eq "$(read_temp_c "${TMP}/t3")" -5 'negative millidegrees'
printf '150\n' > "${TMP}/t4"; expect_eq "$(read_temp_c "${TMP}/t4")" 150 'upper bound'
printf -- '-40\n' > "${TMP}/t5"; expect_eq "$(read_temp_c "${TMP}/t5")" -40 'lower bound'
printf 'abc\n' > "${TMP}/t6"; if read_temp_c "${TMP}/t6" >/dev/null 2>&1; then fail 'non-numeric temp accepted'; fi
printf '999999\n' > "${TMP}/t7"; if read_temp_c "${TMP}/t7" >/dev/null 2>&1; then fail 'out of range temp accepted'; fi
printf -- '-41\n' > "${TMP}/t8"; if read_temp_c "${TMP}/t8" >/dev/null 2>&1; then fail 'below lower bound accepted'; fi
if read_temp_c "${TMP}/missing" >/dev/null 2>&1; then fail 'missing file accepted'; fi

# fresh_enough: file mtime and optional snapshot age against the max age
# (default 300 s, override via MT5700M_TEMP_MAX_AGE).
touch "${TMP}/fresh"
touch -d '10 seconds ago' "${TMP}/old10"
touch -d '400 seconds ago' "${TMP}/old400"
touch -d '10 seconds' "${TMP}/future"
fresh_enough "${TMP}/fresh" || fail 'fresh file rejected'
fresh_enough "${TMP}/old10" || fail '10 s old file rejected'
if fresh_enough "${TMP}/old400"; then fail '400 s old file accepted (default age)'; fi
fresh_enough "${TMP}/fresh" 120 || fail 'snapshot age within limit rejected'
if fresh_enough "${TMP}/fresh" 400; then fail 'snapshot age over limit accepted'; fi
if fresh_enough "${TMP}/future"; then fail 'future mtime accepted'; fi
MT5700M_TEMP_MAX_AGE=60
export MT5700M_TEMP_MAX_AGE
touch -d '100 seconds ago' "${TMP}/old100"
if fresh_enough "${TMP}/old100"; then fail 'override max age ignored'; fi
fresh_enough "${TMP}/old10" || fail 'file within override age rejected'
unset MT5700M_TEMP_MAX_AGE || true

# parse_mt5700m_cache: <rounded temp>|<updated>, both fields required.
printf 'temperature=43.6\ntemperature_sensor=modem2\nupdated=1700000000\n' > "${TMP}/m1"
expect_eq "$(parse_mt5700m_cache "${TMP}/m1")" '44|1700000000' 'mt5700m cache parse'
printf 'temperature=-3.5\nupdated=42\n' > "${TMP}/m2"
expect_eq "$(parse_mt5700m_cache "${TMP}/m2")" '-4|42' 'mt5700m negative rounding'
printf 'temperature=999\nupdated=42\n' > "${TMP}/m3"
expect_eq "$(parse_mt5700m_cache "${TMP}/m3")" '' 'mt5700m out of range'
printf 'temperature=20\n' > "${TMP}/m4"
expect_eq "$(parse_mt5700m_cache "${TMP}/m4")" '' 'mt5700m missing updated'

# parse_5gmodem_metrics: <modem>|<age>|<mtemp> in one pass; missing keys are
# empty, the modem may be unquoted or missing ("-").
printf '{"modem":"Fibocom FM350-GL","age":"12","mtemp":"41.5"}\n' > "${TMP}/g1"
expect_eq "$(parse_5gmodem_metrics "${TMP}/g1")" 'Fibocom FM350-GL|12|41.5' 'metrics parse'
printf '{"modem":"-","age":"3","mtemp":"38"}\n' > "${TMP}/g2"
expect_eq "$(parse_5gmodem_metrics "${TMP}/g2")" '-|3|38' 'metrics missing modem'
printf '{"age":45,"modem":"Quectel RM520N-GL"}\n' > "${TMP}/g3"
expect_eq "$(parse_5gmodem_metrics "${TMP}/g3")" 'Quectel RM520N-GL|45|' 'metrics missing mtemp'
printf '{\n  "modem": "FM350",\n  "age": "7",\n  "mtemp": "40.2"\n}\n' > "${TMP}/g4"
expect_eq "$(parse_5gmodem_metrics "${TMP}/g4")" 'FM350|7|40.2' 'metrics multi-line'
printf 'garbage\n' > "${TMP}/g5"
expect_eq "$(parse_5gmodem_metrics "${TMP}/g5")" '||' 'metrics garbage'
printf '{"path":"2-1","iface":"modem","conn_time":"0d, 00:07:17","modem":"Fibocom FM350-GL","mtemp":"28.0 &deg;C"}\n' > "${TMP}/g6"
expect_eq "$(parse_5gmodem_metrics "${TMP}/g6")" 'Fibocom FM350-GL||28.0 &deg;C' 'metrics iface-value must not match the modem key'

echo 'library unit tests passed'
