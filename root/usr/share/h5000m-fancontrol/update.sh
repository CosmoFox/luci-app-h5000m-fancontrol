#!/bin/sh
#
# Check for / install the latest luci-app-h5000m-fancontrol release from GitHub
# right from the LuCI page. Prints a small JSON object. Translations ship
# inside the main package (usr/lib/lua/luci/i18n), so no separate language
# packs are downloaded or installed here.
#
# Usage:
#   update.sh check [beta]    - compare installed vs latest (stable or beta) release
#   update.sh install [stage] - download + install the app;
#                               stage: stable | beta | current (reinstall the release on record)
#   update.sh status          - print the result file of a background install
#   update.sh version         - print the installed package version only
#
# Robustness notes (backported from luci-app-5gmodem):
# - Assets are fetched through the GitHub API asset URL with an
#   "Accept: application/octet-stream" header: the browser_download_url host
#   (github.com) answers with a Content-Security-Policy header line over 4 KB,
#   and uclient-fetch (wget on OpenWrt) waits for the end of such a line until
#   the timeout, stalling the download.
# - All GitHub JSON is parsed with jsonfilter instead of sed one-liners, the
#   /releases/latest response is cached for 5 minutes, the download reports
#   real byte progress (done/total), is verified against the asset size and
#   is preceded by a /tmp free-space check; package manager failures carry a
#   "detail" field with the tail of its log.
#

REPO="CosmoFox/luci-app-h5000m-fancontrol"
API="https://api.github.com/repos/$REPO/releases/latest"
API_LIST="https://api.github.com/repos/$REPO/releases?per_page=50"
PAGE="https://github.com/$REPO/releases/latest"
PKG="luci-app-h5000m-fancontrol"
TMP=/tmp
STATUS="$TMP/h5000m_fancontrol_update.json"
LOCK="$TMP/h5000m_fancontrol_update.pid"
# Cached /releases/latest response (5 min TTL) - fewer GitHub API hits.
APIC="$TMP/h5000m_fancontrol_update.api.json"
# Package manager output of the running install - tail goes into failures.
LOG="$TMP/h5000m_fancontrol_update.log"
# Current install sub-step (e.g. "deps" while refreshing apk package lists).
STEPF="$TMP/h5000m_fancontrol_update.step"
# Full tag of the last release actually installed (persists across reboots so
# prereleases of the installed base version can be offered again, e.g. a new
# v2.3.1-beta.7 after v2.3.1-beta.6, whose package version is identical).
TAGSTATE="/etc/h5000m_fancontrol.last_tag"

json_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r' | tr '\n\t' '  '; }

# Base64-encode (release notes travel inside JSON); busybox base64, then
# openssl, then a pure-awk fallback for the tiniest images.
b64() {
	if command -v base64 >/dev/null 2>&1; then printf '%s' "$1" | base64 | tr -d '\n'; return; fi
	if command -v openssl >/dev/null 2>&1; then printf '%s' "$1" | openssl base64 | tr -d '\n'; return; fi
	printf '%s' "$1" | hexdump -v -e '/1 "%u\n"' | awk '
		BEGIN { t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" }
		{ b[n++] = $1 }
		END {
			for (i = 0; i < n; i += 3) {
				x = b[i] * 65536 + (i + 1 < n ? b[i + 1] : 0) * 256 + (i + 2 < n ? b[i + 2] : 0)
				printf "%c", substr(t, int(x / 262144) % 64 + 1, 1)
				printf "%c", substr(t, int(x / 4096) % 64 + 1, 1)
				printf "%c", i + 1 < n ? substr(t, int(x / 64) % 64 + 1, 1) : "="
				printf "%c", i + 2 < n ? substr(t, x % 64 + 1, 1) : "="
			}
		}'
}

pkgman() {
	command -v apk >/dev/null 2>&1 && { echo apk; return; }
	command -v opkg >/dev/null 2>&1 && { echo opkg; return; }
	echo ""
}

installed_version() {
	case "$1" in
	apk)  apk info -v 2>/dev/null | sed -n "s/^$PKG-\([0-9][0-9.]*\)-r[0-9].*/\1/p" | head -n1 ;;
	opkg) opkg list-installed "$PKG" 2>/dev/null | sed -n "s/^$PKG - \([0-9][0-9.]*\).*/\1/p" | head -n1 ;;
	esac
}

# Display version of the installed release: the base version from the package
# manager, extended with the -beta.N suffix when the tag on record (TAGSTATE)
# shares that base. apk/opkg cannot tell a stable from a prerelease build of
# the same package version, so the tag is the only reliable source for it.
current_display() {
	_v="$1"
	if [ -s "$TAGSTATE" ]; then
		_t=$(cat "$TAGSTATE" 2>/dev/null)
		_b=${_t#v}; _b=${_b%%-*}
		if [ -n "$_b" ] && [ "$_b" = "$_v" ]; then
			printf '%s\n' "$_t" | sed 's/^v//'
			return
		fi
	fi
	echo "$_v"
}

# net_fetch <timeout_s> <url> [outfile] [header] - to file when given, else to
# stdout; <header> is one optional request header, e.g.
# "Accept: application/octet-stream".
net_fetch() {
	_nf_t="$1"; _nf_u="$2"; _nf_o="$3"; _nf_h="$4"
	if [ -n "$_nf_o" ]; then
		wget -qO "$_nf_o" ${_nf_h:+"--header=$_nf_h"} --timeout="$_nf_t" "$_nf_u" 2>/dev/null && [ -s "$_nf_o" ] && return 0
		rm -f "$_nf_o" 2>/dev/null
	else
		_nf_b=$(wget -qO- ${_nf_h:+"--header=$_nf_h"} --timeout="$_nf_t" "$_nf_u" 2>/dev/null)
		[ -n "$_nf_b" ] && { printf '%s' "$_nf_b"; return 0; }
	fi
	return 1
}

# api_json [fresh] - /releases/latest JSON, cached for 5 minutes. The cache
# keeps the JSON pretty-printed (jsonfilter reads it either way); the write
# goes through a temp file so readers never see a partial document.
api_json() {
	if [ "$1" != fresh ] && [ -s "$APIC" ] && [ -n "$(find "$APIC" -mmin -5 2>/dev/null)" ]; then
		cat "$APIC"; return 0
	fi
	_aj=$(net_fetch 15 "$API") || return 1
	printf '%s' "$_aj" | jsonfilter -e '@.tag_name' >/dev/null 2>&1 || return 1
	printf '%s' "$_aj" > "$APIC.tmp" && mv "$APIC.tmp" "$APIC"
	printf '%s' "$_aj"
}

# The most recent GitHub prerelease, chosen as the newest v<base>-beta.<N>
# tag over the whole release listing. GitHub orders releases by the time the
# release record was created, which can disagree with the build order of the
# tags, so the first "prerelease": true in the listing is not always the
# newest beta - compare the tag numbers instead.
latest_beta() {
	_j=$(net_fetch 15 "$API_LIST") || return 1
	BEST=""; BEST_B=""; BEST_N=-1
	for _t in $(printf '%s' "$_j" | jsonfilter -e '@[*].tag_name' 2>/dev/null); do
		case "$_t" in
		v[0-9]*-beta.[0-9]*) ;;
		*) continue ;;
		esac
		_tb=${_t#v}; _tb=${_tb%%-*}
		_tn=${_t##*-beta.}
		case "$_tn" in ''|*[!0-9]*) continue ;; esac
		if [ "$BEST_B" = "$_tb" ]; then
			[ "$_tn" -gt "$BEST_N" ] && { BEST="$_t"; BEST_B="$_tb"; BEST_N="$_tn"; }
		elif [ -z "$BEST_B" ] || [ "$(version_gt "$_tb" "$BEST_B")" = 1 ]; then
			BEST="$_t"; BEST_B="$_tb"; BEST_N="$_tn"
		fi
	done
	[ -n "$BEST" ] && { echo "$BEST"; return 0; }
	return 1
}

# JSON of one release by tag (assets included).
release_json() {
	[ -n "$1" ] || return 1
	net_fetch 15 "https://api.github.com/repos/$REPO/releases/tags/$1"
}

# asset_name <json> <basename> <ext> - the file name of a matching asset,
# anchored on the package base and accepting both the apk ('-') and ipk ('_')
# name-to-version separators plus the ipk '_all' architecture suffix.
asset_name() {
	[ -n "$1" ] || return 1
	printf '%s' "$1" | jsonfilter -e '@.assets[*].name' 2>/dev/null \
		| grep -E "^$2[-_][0-9][0-9.]*-r[0-9]+([-_.][a-z_]+)?\.$3\$" | head -n1
}

# asset_field <json> <asset name> <field> - one field (url, browser_download_url
# or size) of the named asset.
asset_field() {
	printf '%s' "$1" | jsonfilter -e "@.assets[@.name='$2'].$3" 2>/dev/null | head -n1
}

# ver_from_name <asset file name> - the package version baked into the file
# name (...-2.5.5-r1.apk, ..._2.5.5-r1_all.ipk).
ver_from_name() {
	printf '%s' "$1" | sed -n 's/^.*[-_]\([0-9][0-9.]*\)-r[0-9][0-9]*[-_.].*$/\1/p'
}

# version_gt <a> <b> - prints 1 if a > b else 0 (numeric, dot-separated)
version_gt() {
	awk -v a="$1" -v b="$2" 'BEGIN{
		n=split(a,x,"."); m=split(b,y,".");
		k=(n>m)?n:m;
		for(i=1;i<=k;i++){ai=(i<=n)?x[i]+0:0; bi=(i<=m)?y[i]+0:0;
			if(ai>bi){print 1; exit} if(ai<bi){print 0; exit}}
		print 0
	}'
}

fsize() { [ -f "$1" ] && wc -c < "$1" 2>/dev/null | tr -d ' ' || echo 0; }

# Failure JSON with the package manager log tail in "detail" and the
# offending package list in "pkgs", so the page can explain the error. PM and
# TARGET are the caller's globals.
fail() {
	printf '{"success":false,"error":"%s","detail":"%s","current":"%s","target":"%s","pkgs":"%s"}\n' \
		"$(json_esc "$1")" "$(json_esc "$(tail -n 4 "$LOG" 2>/dev/null)")" \
		"$(json_esc "$(installed_version "$PM")")" "$(json_esc "$TARGET")" "$(json_esc "$2")"
}

# Packages /etc/apk/world requires that apk cannot find (usually a package
# once installed from a file): apk then refuses ANY install, not only ours.
# Parsed out of the apk error log ($LOG).
apk_world_blockers() {
	awk '/^  [^ ].* \(no such package\):/ { n = $1; next }
		n != "" && /required by: world\[/ { print n; n = ""; next }
		/^  [^ ]/ { n = "" }' "$LOG" 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//'
}

# apk fails with "unable to select packages" when its package lists are
# stale; refresh them once and retry when no unrelated package blocks it.
# Installs $F, logging into $LOG; "deps" is recorded in $STEPF while the
# package lists are refreshed so the page can show the sub-step.
apk_install() {
	apk add --allow-untrusted "$F" >"$LOG" 2>&1 && return 0
	grep -q 'unable to select packages' "$LOG" 2>/dev/null || return 1
	[ -z "$(apk_world_blockers)" ] || return 1
	logger -t h5000m-fancontrol "update: apk could not resolve dependencies - refreshing package lists and retrying"
	echo deps > "$STEPF"
	apk update >/dev/null 2>&1
	apk add --allow-untrusted "$F" >"$LOG" 2>&1
}

# Live progress snapshot for the page poll. TARGET names the release being
# installed; done/total are bytes for the download/install stages.
progress() {
	printf '{"running":true,"stage":"%s","done":%s,"total":%s,"target":"%s","step":"%s"}\n' \
		"$1" "${2:-0}" "${3:-0}" "$(json_esc "$TARGET")" "$(json_esc "${4:-}")" > "$STATUS.tmp" \
		&& mv "$STATUS.tmp" "$STATUS"
}

if [ -z "${H5FAN_UPDATE_SOURCED:-}" ]; then
case "$1" in
check)
	PM=$(pkgman)
	CUR=$(installed_version "$PM")
	CUR_DISP=$(current_display "$CUR")
	# Distinguish "no network" (empty body) from "no stable release yet"
	# (GitHub answers releases/latest with HTTP 404 when only prereleases
	# exist - a non-empty body without any tag_name).
	J=$(api_json fresh)
	LAT=""
	[ -n "$J" ] && LAT=$(printf '%s' "$J" | jsonfilter -e '@.tag_name' 2>/dev/null)
	LATV=${LAT#v}
	AVAIL=0
	if [ -n "$LATV" ] && [ -n "$CUR" ]; then
		AVAIL=$(version_gt "$LATV" "$CUR")
	elif [ -n "$LATV" ] && [ -z "$CUR" ]; then
		AVAIL=1
	fi
	# Only when asked for; the releases list call is heavier than /releases/latest.
	BETA_LAT=""
	BETA_AVAIL=0
	if [ "$2" = "beta" ]; then
		BETA_LAT=$(latest_beta)
		if [ -n "$BETA_LAT" ]; then
			BETAV=${BETA_LAT#v}; BETAV=${BETAV%%-*}
			if [ -n "$BETAV" ] && [ -n "$CUR" ]; then
				BETA_AVAIL=$(version_gt "$BETAV" "$CUR")
			elif [ -n "$BETAV" ] && [ -z "$CUR" ]; then
				BETA_AVAIL=1
			fi
			# Prereleases of the installed base version have the same package
			# version, so also offer one whenever its tag differs from the
			# release that is currently installed.
			if [ "$BETA_AVAIL" = 0 ] && [ "$BETA_LAT" != "$(cat "$TAGSTATE" 2>/dev/null)" ]; then
				BETA_AVAIL=1
			fi
		fi
	fi
	NOTES=""
	PUB=""
	if [ -n "$J" ]; then
		# Release notes travel base64-encoded inside the JSON; cap their size
		# so a huge release body cannot bloat the page response.
		NOTES=$(printf '%s' "$J" | jsonfilter -e '@.body' 2>/dev/null | head -c 8192)
		PUB=$(printf '%s' "$J" | jsonfilter -e '@.published_at' 2>/dev/null)
	fi
	if [ -z "$J" ]; then
		printf '{"success":false,"error":"Could not reach GitHub","pm":"%s","current":"%s","beta_latest":"%s","beta_available":%s}\n' \
			"$PM" "$(json_esc "$CUR_DISP")" "$(json_esc "$BETA_LAT")" "$BETA_AVAIL"
		exit 0
	fi
	printf '{"success":true,"pm":"%s","current":"%s","latest":"%s","update_available":%s,"release_url":"%s","published":"%s","notes":"%s","beta_latest":"%s","beta_available":%s}\n' \
		"$PM" "$(json_esc "$CUR_DISP")" "$(json_esc "$LAT")" "$AVAIL" "$PAGE" "$(json_esc "$PUB")" "$(b64 "$NOTES")" \
		"$(json_esc "$BETA_LAT")" "$BETA_AVAIL"
	;;

install)
	STAGE=${2:-stable}
	# Any further arguments (e.g. language codes sent by an older page cache
	# when translation packs were still downloaded) are ignored: translations
	# ship inside the main package now.
	# The download + install can take longer than the LuCI RPC/XHR timeout, so
	# run it in the background, write the result to a status file, and let the
	# page poll 'update.sh status'. A second install over a running one is not
	# started (both would write the same result file).
	if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
		echo '{"started":true,"already":true}'
		exit 0
	fi
	rm -f "$STATUS" "$STATUS.tmp" "$STATUS.res" "$LOG" "$STEPF"
	# Create the progress file right away so the page can poll it (the script
	# binary itself is replaced during the update).
	echo '{"running":true}' > "$STATUS"
	echo '{"started":true}'
	(
		do_install() {
			TARGET=""
			PM=$(pkgman)
			[ -n "$PM" ] || { fail "No package manager found"; return; }
			case "$PM" in apk) EXT=apk ;; opkg) EXT=ipk ;; esac
			# Beta releases are built from pre-release tags only (their assets
			# then differ in build number, not version). Fall back to stable when
			# no beta is published yet.
			TAG=""; RELJSON=""
			if [ "$STAGE" = "beta" ]; then
				TAG=$(latest_beta)
				[ -n "$TAG" ] && RELJSON=$(release_json "$TAG")
			elif [ "$STAGE" = "current" ]; then
				# Reinstall the exact release whose tag is on record as the
				# installed one - scanning the release list would be ambiguous
				# for a prerelease of the same base version as a stable release.
				TAG=$(cat "$TAGSTATE" 2>/dev/null)
				if [ -z "$TAG" ]; then
					fail "unknown_current_release"
					return
				fi
				RELJSON=$(release_json "$TAG")
				if [ -z "$RELJSON" ]; then
					fail "Could not reach GitHub"
					return
				fi
			fi
			if [ -z "$RELJSON" ]; then
				STAGE=stable
				RELJSON=$(api_json)
			fi
			if [ -z "$RELJSON" ]; then
				fail "Could not reach GitHub"
				return
			fi
			# Full tag of the release we are about to install - recorded in
			# TAGSTATE so later prereleases of the same base version are offered.
			TAGG=""
			[ -n "$TAG" ] && TAGG="$TAG"
			if [ -z "$TAGG" ]; then
				TAGG=$(printf '%s' "$RELJSON" | jsonfilter -e '@.tag_name' 2>/dev/null)
			fi
			if [ -z "$TAGG" ]; then
				# /releases/latest answers 404 (a non-empty body without a tag)
				# while GitHub has only prereleases. No stable release yet.
				fail "No stable release published yet"
				return
			fi
			PREV=$(installed_version "$PM")
			INSTALLED=""
			STEP=0
			BASE="$PKG"
			STEP=$((STEP+1))
			NAME=$(asset_name "$RELJSON" "$BASE" "$EXT")
			if [ -z "$NAME" ]; then
				# Tag published but CI hasn't built the asset yet.
				fail "asset_pending"; return
			fi
				# The API address of the asset, not browser_download_url:
				# github.com answers the latter with a Content-Security-Policy
				# line over 4 KB, and uclient-fetch waits for the end of a header
				# line longer than its 4 KB buffer until the timeout. The API
				# redirects straight to the file server with short headers.
				AURL=$(asset_field "$RELJSON" "$NAME" url)
				URL="$AURL"
				ACC="Accept: application/octet-stream"
				if [ -z "$URL" ]; then
					URL=$(asset_field "$RELJSON" "$NAME" browser_download_url)
					ACC=""
				fi
				if [ -z "$URL" ]; then
					fail "asset_pending"; return
				fi
				TOTAL=$(asset_field "$RELJSON" "$NAME" size)
				case "$TOTAL" in ''|*[!0-9]*) TOTAL=0 ;; esac
				# Version we are about to install, from the asset FILE NAME
				# - later verified against what the package manager reports.
				TARGET=$(ver_from_name "$NAME")
				_free=$(df -k "$TMP" 2>/dev/null | awk 'NR==2 {print $4}')
				case "$_free" in ''|*[!0-9]*) _free=0 ;; esac
				if [ "$TOTAL" -gt 0 ] && [ "$_free" -gt 0 ] && [ $((_free * 1024)) -lt $((TOTAL * 2)) ]; then
					fail "no_space"; return
				fi

				F="$TMP/$BASE.$EXT"
				rm -f "$F" "$F.ok" "$F.rc"
				progress download 0 "$TOTAL"
				# Download in the background and poll the file size, so the page
				# sees real byte progress instead of a stalled bar.
				( net_fetch 120 "$URL" "$F" "$ACC" && : > "$F.ok" ) >/dev/null 2>&1 </dev/null &
				_dp=$!
				while kill -0 "$_dp" 2>/dev/null; do
					progress download "$(fsize "$F")" "$TOTAL"
					sleep 1
				done
				wait "$_dp" 2>/dev/null
				if [ ! -f "$F.ok" ] || [ ! -s "$F" ]; then
					rm -f "$F" "$F.ok"
					fail "download_failed" "$BASE"; return
				fi
				rm -f "$F.ok"
				_got=$(fsize "$F")
				if [ "$TOTAL" -gt 0 ] && [ "$_got" != "$TOTAL" ]; then
					rm -f "$F"
					fail "download_incomplete" "$BASE"; return
				fi

				rm -f "$STEPF" "$F.rc"
				progress install "$_got" "$TOTAL"
				# Same for the package manager call: keep reporting progress
				# (including the apk deps-refresh sub-step) while it runs.
				(
					if [ "$PM" = apk ]; then
						apk_install
					else
						opkg install --force-reinstall "$F" >"$LOG" 2>&1
					fi
					echo $? > "$F.rc"
				) >/dev/null 2>&1 </dev/null &
				_ip=$!
				while kill -0 "$_ip" 2>/dev/null; do
					progress install "$_got" "$TOTAL" "$(cat "$STEPF" 2>/dev/null)"
					sleep 1
				done
				wait "$_ip" 2>/dev/null
				_rc=$(cat "$F.rc" 2>/dev/null)
				[ -n "$_rc" ] || _rc=1
				rm -f "$F" "$F.rc" "$STEPF"

				# Version from the asset FILE NAME to tell a real failure from a
				# non-zero exit when the package actually landed.
				_want=$(ver_from_name "$NAME")
				if [ "$_rc" != 0 ]; then
					if [ -n "$_want" ] && [ "$(installed_version "$PM")" = "$_want" ]; then
						logger -t h5000m-fancontrol "update: $PM returned $_rc, but $BASE $_want is installed - treating as success"
					else
						if [ "$PM" = apk ]; then
							_wb=$(apk_world_blockers)
							if [ -n "$_wb" ]; then
								logger -t h5000m-fancontrol "update: apk refuses any install - /etc/apk/world lists packages it cannot find: $_wb"
								fail "world_broken" "$_wb"; return
							fi
						fi
						fail "install_failed" "$BASE"; return
					fi
				fi
				INSTALLED="$INSTALLED $BASE"
				progress install 100 100
			INSTALLED="${INSTALLED# }"
			progress finish 100 100
			# Drop LuCI's cached indexes/modules so the new bundle is served.
			rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null
			CUR=$(installed_version "$PM")
			# Verify the version actually matches the release we installed;
			# opkg/apk return 0 even when the asset was built with the
			# already-installed version. When the asset name gave no version at
			# all, fall back to "the installed version at least changed".
			if { [ -n "$TARGET" ] && [ "$CUR" = "$TARGET" ]; } \
				|| { [ -z "$TARGET" ] && [ -n "$PREV" ] && [ "$CUR" != "$PREV" ]; }; then
				[ "$_rc" = 0 ] || logger -t h5000m-fancontrol "update: $PM returned $_rc, but $PKG $TARGET is installed - treating as success"
				printf '{"success":true,"installed":"%s","current":"%s","previous":"%s","target":"%s"%s,"stage":"%s"}\n' \
					"$(json_esc "$INSTALLED")" "$(json_esc "$CUR")" "$(json_esc "$PREV")" "$(json_esc "$TARGET")" \
					"$([ "$PREV" = "$CUR" ] && echo ',"reinstalled":1')" "$STAGE"
				[ -n "$TAGG" ] && printf '%s\n' "$TAGG" > "$TAGSTATE"
				return
			fi
			fail "version_mismatch" "$PKG"
		}
		# Write to a separate temp file and move into place only when done: the
		# progress snapshots above move STATUS.tmp away continuously, so the
		# final result must live in its own file. The lock holds the subshell
		# PID ($$ would be the parent, which already exited).
		read -r _upid _ < /proc/self/stat 2>/dev/null
		echo "$_upid" > "$LOCK" 2>/dev/null
		do_install > "$STATUS.res" 2>/dev/null
		mv "$STATUS.res" "$STATUS"
		rm -f "$LOCK"
	) >/dev/null 2>&1 </dev/null &
	# rpcd's file exec backend can lose the script exit when it spawns a
	# background child and finishes instantly; pause so the response flushes.
	sleep 1
	exit 0
	;;

status)
	if [ -s "$STATUS" ]; then
		cat "$STATUS"
	elif [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
		echo '{"running":true}'
	else
		echo '{"idle":true}'
	fi
	;;

version)
	PM=$(pkgman)
	V=$(installed_version "$PM")
	printf '{"installed":"%s","pm":"%s"}\n' "$(json_esc "$(current_display "$V")")" "$PM"
	;;

install-5gmodem)
	# Offer the 5gmodem stack (fildunsky/luci-app-5gmodem): it publishes the
	# modem metrics this app reads. Downloads the latest full (non-lite)
	# release asset (.apk on apk snapshots, .ipk on opkg) and installs it.
	PM=$(pkgman)
	[ -n "$PM" ] || { echo '{"success":false,"error":"No package manager found"}'; exit 0; }
	case "$PM" in apk) EXT=apk ;; opkg) EXT=ipk ;; esac
	BODY=$(net_fetch 15 "https://api.github.com/repos/fildunsky/luci-app-5gmodem/releases/latest" | tr -d '\n\r')
	[ -n "$BODY" ] || { echo '{"success":false,"error":"Could not reach GitHub"}'; exit 0; }
	TAGG=$(printf '%s' "$BODY" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
	URL=$(printf '%s' "$BODY" | sed -n 's|.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*/luci-app-5gmodem[-_][0-9][^"]*\.'"$EXT"'\)".*|\1|p' | head -n1)
	if [ -z "$URL" ]; then
		printf '{"success":false,"error":"No luci-app-5gmodem .%s asset in the latest release (%s)"}\n' "$EXT" "$(json_esc "$TAGG")"
		exit 0
	fi
	F="$TMP/luci-app-5gmodem.$EXT"
	rm -f "$F"
	if ! net_fetch 180 "$URL" "$F"; then
		rm -f "$F"
		echo '{"success":false,"error":"Download failed"}'
		exit 0
	fi
	if [ "$PM" = "apk" ]; then
		apk add --allow-untrusted "$F" >/dev/null 2>&1; _rc=$?
	else
		opkg install "$F" >/dev/null 2>&1; _rc=$?
	fi
	rm -f "$F"
	if [ "$_rc" != 0 ]; then
		printf '{"success":false,"error":"Package manager returned %s"}\n' "$_rc"
		exit 0
	fi
	if [ "$PM" = "apk" ]; then
		V=$(apk info -v 2>/dev/null | sed -n 's/^luci-app-5gmodem-\([0-9][0-9.]*\)-r[0-9].*/\1/p' | head -n1)
	else
		V=$(opkg list-installed "luci-app-5gmodem" 2>/dev/null | sed -n 's/^luci-app-5gmodem - \([0-9][0-9.]*\).*/\1/p' | head -n1)
	fi
	[ -n "$V" ] || V=${TAGG#v}
	printf '{"success":true,"installed":"%s","tag":"%s"}\n' "$(json_esc "$V")" "$(json_esc "$TAGG")"
	;;

*)
	echo '{"success":false,"error":"usage: update.sh check [beta]|install [stable|beta|current]|status|version"}'
	exit 1
	;;
esac
fi
