#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONTROLLER="${ROOT}/root/usr/sbin/h5000m-fancontrol"

if grep -Eq 'echo[[:space:]]+user_space[[:space:]]*>.*policy' "${CONTROLLER}"; then
	echo 'The fan controller must not replace the CPU thermal governor.' >&2
	exit 1
fi
grep -q 'release_thermal_control' "${CONTROLLER}"
grep -q 'kernel must' "${CONTROLLER}"

echo 'thermal policy safety tests passed'
