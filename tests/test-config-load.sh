#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONTROLLER="${ROOT}/root/usr/sbin/h5000m-fancontrol"
LIB="${ROOT}/root/usr/share/h5000m-fancontrol/lib.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

BIN="${TMP}/bin"
mkdir -p "${BIN}"

# Fake `uci show` returning a config with out-of-range, invalid and legacy
# values; load_config must fall back and clamp exactly like the previous
# per-option lookups did.
cat > "${BIN}/uci" <<'EOF'
#!/bin/sh
if [ "$1" = "-q" ] && [ "$2" = "show" ]; then
	cat <<'CFG'
h5000m_fancontrol.settings=settings
h5000m_fancontrol.settings.enabled='0'
h5000m_fancontrol.settings.mode='off'
h5000m_fancontrol.settings.curve='custom'
h5000m_fancontrol.settings.temp_source='cpu'
h5000m_fancontrol.settings.manual_pwm='abc'
h5000m_fancontrol.settings.interval='999'
h5000m_fancontrol.settings.hysteresis='99'
h5000m_fancontrol.settings.down_delay='30'
h5000m_fancontrol.settings.start_pwm='192'
h5000m_fancontrol.settings.start_boost_ms='700'
h5000m_fancontrol.settings.fail_pwm='255'
h5000m_fancontrol.settings.override_floor='1'
h5000m_fancontrol.settings.curve_custom='30:10,60:80'
CFG
	exit 0
fi
exit 1
EOF
chmod +x "${BIN}/uci"
PATH="${BIN}:${PATH}"
export PATH

output="$(H5000M_FAN_LIB="${LIB}" sh "${CONTROLLER}" status 2>/dev/null)"

expect_line() { # <exact line> <label>
	printf '%s\n' "${output}" | grep -qx "$1" || {
		echo "FAIL: $2: missing line [$1]" >&2
		exit 1
	}
}

expect_line 'enabled=0' 'enabled parsed'
expect_line 'mode=kernel' 'legacy mode off mapped to kernel'
expect_line 'curve=custom' 'custom profile parsed'
expect_line 'temp_source=cpu' 'temp_source parsed'
expect_line 'manual_pwm=160' 'invalid manual_pwm falls back'
expect_line 'interval=60' 'interval clamped to max'
expect_line 'hysteresis=10' 'hysteresis clamped to max'
expect_line 'down_delay=30' 'down_delay parsed'
expect_line 'override_floor=1' 'override_floor parsed'
expect_line 'curve_data=30:10,60:80' 'custom curve string parsed verbatim'

echo 'config load tests passed'
