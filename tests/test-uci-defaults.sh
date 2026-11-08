#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

STORE="${TMP}/store"
BIN="${TMP}/bin"
mkdir -p "${BIN}"
touch "${STORE}"

# Minimal fake `uci` backed by a flat key=value store (key = full dotted path).
cat > "${BIN}/uci" <<'EOF'
#!/bin/sh
store="$FAKE_UCI_STORE"
cmd="$1"
[ "$cmd" = "-q" ] && { shift; cmd="$1"; }
case "$cmd" in
	get)
		key="$2"
		val="$(sed -n "s|^${key}=||p" "$store" | head -n 1)"
		[ -n "$val" ] && { printf '%s\n' "$val"; exit 0; }
		exit 1
		;;
	set)
		arg="$2"
		key="${arg%%=*}"; val="${arg#*=}"
		[ "$key" = "$arg" ] && exit 1
		grep -v "^${key}=" "$store" > "${store}.tmp" 2>/dev/null || true
		printf '%s=%s\n' "$key" "$val" >> "${store}.tmp"
		mv "${store}.tmp" "$store"
		;;
	delete)
		grep -v "^$2=" "$store" > "${store}.tmp" 2>/dev/null || true
		mv "${store}.tmp" "$store"
		;;
	commit) ;;
	*) exit 1 ;;
esac
exit 0
EOF
chmod +x "${BIN}/uci"
PATH="${BIN}:${PATH}"
export PATH

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

expect_val() { # <uci key> <expected> <label>
	val="$(FAKE_UCI_STORE="${STORE}" uci -q get "$1" || true)"
	[ "$val" = "$2" ] || fail "$3: expected [$2], got [$val]"
}

expect_missing() { # <uci key> <label>
	if FAKE_UCI_STORE="${STORE}" uci -q get "$1" >/dev/null 2>&1; then
		fail "$2: $1 still set"
	fi
}

run_migration() { # <script> [store]
	FAKE_UCI_STORE="${2:-${STORE}}" sh "${ROOT}/root/etc/uci-defaults/$1" >/dev/null 2>&1 \
		|| fail "$1 exited non-zero"
}

# Scenario 1: fresh install - the full 91 -> 92 -> 93 chain.
run_migration 91-h5000m-fancontrol-v2
expect_val h5000m_fancontrol.settings.schema_version 2 '91 sets schema 2'
expect_val h5000m_fancontrol.settings.interval 5 '91 default interval'
expect_val h5000m_fancontrol.settings.temp_source max '91 default temp_source'
expect_val h5000m_fancontrol.settings.start_boost_ms 700 '91 default boost'
expect_val h5000m_fancontrol.settings.fail_pwm 255 '91 default fail_pwm'
expect_val h5000m_fancontrol.settings.curve_silent '20:0,35:0,40:50,55:50,70:60,85:75,95:100' '91 v2 silent curve'
run_migration 92-h5000m-fancontrol-v3
expect_val h5000m_fancontrol.settings.schema_version 3 '92 bumps schema to 3'
expect_val h5000m_fancontrol.settings.curve_silent '20:0,35:0,40:20,50:20,60:40,70:50,85:100,95:100' '92 new silent curve'
run_migration 93-h5000m-fancontrol-v4
expect_val h5000m_fancontrol.settings.schema_version 4 '93 bumps schema to 4'
expect_val h5000m_fancontrol.settings.override_floor 0 '93 default override_floor'

# Idempotency: re-running any migration must not change anything.
run_migration 91-h5000m-fancontrol-v2
expect_val h5000m_fancontrol.settings.schema_version 4 '91 re-run keeps schema 4'
run_migration 92-h5000m-fancontrol-v3
expect_val h5000m_fancontrol.settings.schema_version 4 '92 re-run keeps schema 4'
expect_val h5000m_fancontrol.settings.curve_silent '20:0,35:0,40:20,50:20,60:40,70:50,85:100,95:100' '92 re-run keeps silent curve'
run_migration 93-h5000m-fancontrol-v4
expect_val h5000m_fancontrol.settings.override_floor 0 '93 re-run keeps override_floor'

# Scenario 2: legacy v1 config with mode 'off' and removed options.
STORE2="${TMP}/store2"
printf '%s\n' \
	'h5000m_fancontrol.settings.mode=off' \
	'h5000m_fancontrol.settings.min_pwm=40' \
	'h5000m_fancontrol.settings.enabled=1' > "${STORE2}"
run_migration 91-h5000m-fancontrol-v2 "${STORE2}"
STORE="${STORE2}"
expect_val h5000m_fancontrol.settings.mode kernel '91 maps mode off to kernel'
expect_missing h5000m_fancontrol.settings.min_pwm '91 removes min_pwm'
expect_val h5000m_fancontrol.settings.schema_version 2 '91 legacy schema 2'

# Scenario 3: a custom user curve set at schema 2 survives the v3 migration.
STORE3="${TMP}/store3"
printf '%s\n' \
	'h5000m_fancontrol.settings.schema_version=2' \
	'h5000m_fancontrol.settings.curve_silent=30:10,60:80' > "${STORE3}"
run_migration 92-h5000m-fancontrol-v3 "${STORE3}"
STORE="${STORE3}"
expect_val h5000m_fancontrol.settings.curve_silent '30:10,60:80' '92 keeps user curve'
expect_val h5000m_fancontrol.settings.schema_version 3 '92 custom curve schema 3'

# Scenario 4: schema 3 config gains override_floor from the v4 migration.
STORE4="${TMP}/store4"
printf '%s\n' 'h5000m_fancontrol.settings.schema_version=3' > "${STORE4}"
run_migration 93-h5000m-fancontrol-v4 "${STORE4}"
STORE="${STORE4}"
expect_val h5000m_fancontrol.settings.override_floor 0 '93 adds override_floor'
expect_val h5000m_fancontrol.settings.schema_version 4 '93 schema 3 -> 4'

# Scenario 5: an existing override_floor value is never overwritten.
STORE5="${TMP}/store5"
printf '%s\n' \
	'h5000m_fancontrol.settings.schema_version=3' \
	'h5000m_fancontrol.settings.override_floor=1' > "${STORE5}"
run_migration 93-h5000m-fancontrol-v4 "${STORE5}"
STORE="${STORE5}"
expect_val h5000m_fancontrol.settings.override_floor 1 '93 keeps override_floor=1'

echo 'uci-defaults migration tests passed'
