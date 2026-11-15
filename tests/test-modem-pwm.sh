#!/bin/sh
# Ported from upstream FAN789/luci-app-h5000m-fancontrol@dd61140 (PR #3) and
# adapted to this tree: the controller reads its config with a single
# `uci show` pass, the floor cache path is overridable and the telemetry
# parser is the jq-free lib.sh implementation (nested documents are a
# documented flat-schema assumption, so the upstream nested-payload case is
# replaced with pretty-printed JSON).
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
# No EXIT trap on purpose: Git Bash (msys2) may run an EXIT trap inside
# command substitutions, deleting the fixture mid-run; explicit cleanup at
# the end is portable (dash/busybox ash) and a leftover tmp dir on failure
# beats a flaky test.

# Source only function definitions (never the dispatch case), rerouting the
# literal /sys paths to the fixture.
sed '/^case /,$d' "$ROOT/root/usr/sbin/h5000m-fancontrol" | sed "s|/sys/|$TMP/sys/|g" > "$TMP/functions"

export H5000M_FAN_LIB="$ROOT/root/usr/share/h5000m-fancontrol/lib.sh"
export H5000M_FAN_SENSOR_SYSFS_ROOT="$TMP/sys"
export H5000M_FAN_RADIO_SYSFS_ROOT="$TMP/net"
export H5000M_FAN_5GMODEM_TELE="$TMP/tele.json"
export H5000M_FAN_5GMODEM_TELE_MAX_AGE=90
export H5000M_FAN_MAPCACHE="$TMP/mapcache"
export H5000M_FAN_MT5700M_TEMP_CACHE="$TMP/missing"

. "$TMP/functions"

# The state/policy paths are plain globals; point them at the fixture.
STATE_FILE="$TMP/state"
POLICY_FILE="$TMP/policy"

mkdir -p "$TMP/sys/class/hwmon/hwmon0" "$TMP/sys/class/thermal/thermal_zone0" \
	"$TMP/sys/class/thermal/cooling_device0" "$TMP/net"
pwm="$TMP/sys/class/hwmon/hwmon0/pwm1"
zone="$TMP/sys/class/thermal/thermal_zone0"
echo pwmfan > "$TMP/sys/class/hwmon/hwmon0/name"
echo cpu > "$zone/type"
echo 30000 > "$zone/temp"
echo step_wise > "$zone/policy"
echo 'step_wise user_space' > "$zone/available_policies"
echo pwm-fan > "$TMP/sys/class/thermal/cooling_device0/type"
echo 3 > "$TMP/sys/class/thermal/cooling_device0/max_state"
mkdir -p "$TMP/sys/firmware/devicetree/base/pwm-fan"
printf '\000\000\000\000\000\000\000\300\000\000\000\340\000\000\000\377' > "$TMP/sys/firmware/devicetree/base/pwm-fan/cooling-levels"

uci() {
	printf "h5000m_fancontrol.settings.enabled='%s'\n" "${TEST_ENABLED:-1}"
	printf "h5000m_fancontrol.settings.mode='%s'\n" "${TEST_MODE:-manual}"
	printf "h5000m_fancontrol.settings.manual_pwm='32'\n"
	printf "h5000m_fancontrol.settings.interval='5'\n"
	printf "h5000m_fancontrol.settings.hysteresis='0'\n"
	printf "h5000m_fancontrol.settings.down_delay='0'\n"
	printf "h5000m_fancontrol.settings.start_pwm='192'\n"
	printf "h5000m_fancontrol.settings.start_boost_ms='0'\n"
	printf "h5000m_fancontrol.settings.fail_pwm='255'\n"
	printf "h5000m_fancontrol.settings.override_floor='0'\n"
	printf "h5000m_fancontrol.settings.temp_source='max'\n"
	printf "h5000m_fancontrol.settings.curve='custom'\n"
	printf "h5000m_fancontrol.settings.curve_custom='20:0,150:0'\n"
}
logger() { :; }

check() { # <expected pwm>
	expected="$1"
	rm -f "$STATE_FILE"
	echo 17 > "$pwm"
	apply_once
	test "$(cat "$pwm")" = "$expected"
	test "$(cat "$zone/policy")" = step_wise
	grep -qx "applied_pwm=$expected" "$STATE_FILE"
}

for TEST_MODE in manual auto; do
	export TEST_MODE
	for pair in '0 32' '1 128' '2 192' '3 255' '2.0 192' '3.0 255'; do
		# Intentional word splitting: "therm expected" pairs.
		# shellcheck disable=SC2086
		set -- $pair
		printf '{"therm": %s}\n' "$1" > "$FIVEGMODEM_TELE"
		echo "case: mode=$TEST_MODE therm=$1"
		if [ "$TEST_MODE" = auto ] && [ "$1" = 0 ]; then check 0; else check "$2"; fi
	done
	# Pretty-printed JSON is accepted; strings, fractions, truncated documents
	# and trailing garbage supply no readings.
	printf '{\n  "therm": 3\n}\n' > "$FIVEGMODEM_TELE"
	echo "case: mode=$TEST_MODE pretty-printed therm=3"
	check 255
	for payload in '{"therm":3' '{"therm":"3"}' '{"therm":2.5}' '{"therm":3} garbage'; do
		printf '%s\n' "$payload" > "$FIVEGMODEM_TELE"
		echo "case: mode=$TEST_MODE invalid: $payload"
		if [ "$TEST_MODE" = auto ]; then check 0; else check 32; fi
	done
done

# A stale telemetry file supplies no floor.
printf '{"therm":3}\n' > "$FIVEGMODEM_TELE"
touch -t 202001010000 "$FIVEGMODEM_TELE" 2>/dev/null || touch -d '2 minutes ago' "$FIVEGMODEM_TELE"
TEST_MODE=manual
echo "case: stale file"
check 32

# The kernel cooling floor still wins over a lower modem minimum.
printf '{"therm":1}\n' > "$FIVEGMODEM_TELE"
echo 40000 > "$zone/temp"
echo "case: kernel floor precedence"
check 192
grep -qx 'thermal_floor=192' "$STATE_FILE"
grep -qx 'reason=manual+kernel-floor' "$STATE_FILE"

# Kernel-only and disabled modes leave the fan untouched.
printf '{"therm":3}\n' > "$FIVEGMODEM_TELE"
TEST_MODE=kernel
echo "case: kernel mode"
check 17
grep -qx 'reason=kernel' "$STATE_FILE"
TEST_MODE=manual; TEST_ENABLED=0
echo "case: disabled"
check 17
grep -qx 'reason=kernel' "$STATE_FILE"

echo "test-modem-pwm: all tests passed"
rm -rf "$TMP"
