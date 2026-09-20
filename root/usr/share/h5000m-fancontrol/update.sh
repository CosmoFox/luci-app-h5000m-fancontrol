#!/bin/sh
#
# Check for / install the latest luci-app-h5000m-fancontrol release from GitHub
# right from the LuCI page. Prints a small JSON object. The ru translation
# package is installed along with the app when its matching asset exists.
#
# Usage:
#   update.sh check [beta]    - compare installed vs latest (stable or beta) release
#   update.sh install [stage] - download + install app (+ ru translation);
#                               stage: stable | beta | current (reinstall the release on record)
#   update.sh status          - print the result file of a background install
#   update.sh version         - print the installed package version only
#

REPO="CosmoFox/luci-app-h5000m-fancontrol"
API="https://api.github.com/repos/$REPO/releases/latest"
PAGE="https://github.com/$REPO/releases/latest"
PKG="luci-app-h5000m-fancontrol"
I18N="luci-i18n-h5000m-fancontrol-ru"
TMP=/tmp
STATUS="$TMP/h5000m_fancontrol_update.json"
LOCK="$TMP/h5000m_fancontrol_update.pid"
# Full tag of the last release actually installed (persists across reboots so
# prereleases of the installed base version can be offered again, e.g. a new
# v2.3.1-beta.7 after v2.3.1-beta.6, whose package version is identical).
TAGSTATE="/etc/h5000m_fancontrol.last_tag"

json_esc() { echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

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

# net_fetch <timeout_s> <url> [outfile] - to file when given, else to stdout.
net_fetch() {
	_nf_t="$1"; _nf_u="$2"; _nf_o="$3"
	if [ -n "$_nf_o" ]; then
		wget -qO "$_nf_o" --timeout="$_nf_t" "$_nf_u" 2>/dev/null && [ -s "$_nf_o" ] && return 0
		rm -f "$_nf_o" 2>/dev/null
	else
		_nf_b=$(wget -qO- --timeout="$_nf_t" "$_nf_u" 2>/dev/null)
		[ -n "$_nf_b" ] && { printf '%s' "$_nf_b"; return 0; }
	fi
	return 1
}

api_json() { net_fetch 15 "$API"; }

# The most recent GitHub prerelease (newest -beta.N tag). Only the releases
# list endpoint returns prereleases - releases/latest always resolves to the
# newest stable release. The first "prerelease": true in the newest-first
# listing belongs to the newest built beta; its tag_name sits right before it.
latest_beta() {
	_j=$(net_fetch 15 "https://api.github.com/repos/$REPO/releases?per_page=20" | tr -d '\n\r')
	[ -n "$_j" ] || return 1
	printf '%s' "$_j" | awk '
		{
			# GitHub API emits compact JSON ("prerelease":true), allow both
			# forms; the matched text starts right at the "prerelease" key.
			if (match($0, /"prerelease":[ \t]*true/) == 0) exit
			pr = RSTART
			head = substr($0, 1, pr - 1)
			probe = "\"tag_name\":\""
			pos = 0; last = 0
			while ((q = index(substr(head, pos + 1), probe)) > 0) {
				pos = pos + q
				last = pos
			}
			if (last == 0) exit
			rest = substr(head, last + length(probe))
			if (match(rest, /^[^"]*/)) {
				print substr(rest, 1, RLENGTH)
				exit
			}
		}'
}

# JSON of one release by tag (assets included), collapsed to a single line so
# sed-based extraction below can work on it.
release_json() {
	[ -n "$1" ] || return 1
	net_fetch 15 "https://api.github.com/repos/$REPO/releases/tags/$1" | tr -d '\n\r'
}

# asset_url_in <json> <basename> <ext> - browser_download_url of a matching
# asset inside the given release JSON. The match is anchored on the FILE NAME
# (github.com/<user>/<repo> is part of every asset URL, a bare substring would
# match the wrong one) and accepts both the apk ('-') and ipk ('_') name-to-
# version separators.
asset_url_in() {
	[ -n "$1" ] || return 1
	printf '%s' "$1" | sed -n 's|.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*/'"$2"'[-_][0-9][^"]*\.'"$3"'\)".*|\1|p' | head -n1
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

case "$1" in
check)
	PM=$(pkgman)
	CUR=$(installed_version "$PM")
	# Distinguish "no network" (empty body) from "no stable release yet"
	# (GitHub answers releases/latest with HTTP 404 when only prereleases
	# exist - a non-empty body without any tag_name).
	L_BODY=$(api_json)
	LAT=""
	[ -n "$L_BODY" ] && LAT=$(printf '%s' "$L_BODY" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
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
	if [ -z "$L_BODY" ]; then
		printf '{"success":false,"error":"Could not reach GitHub","pm":"%s","current":"%s","beta_latest":"%s","beta_available":%s}\n' \
			"$PM" "$(json_esc "$CUR")" "$(json_esc "$BETA_LAT")" "$BETA_AVAIL"
		exit 0
	fi
	printf '{"success":true,"pm":"%s","current":"%s","latest":"%s","update_available":%s,"release_url":"%s","beta_latest":"%s","beta_available":%s}\n' \
		"$PM" "$(json_esc "$CUR")" "$(json_esc "$LAT")" "$AVAIL" "$PAGE" "$(json_esc "$BETA_LAT")" "$BETA_AVAIL"
	;;

install)
	STAGE=${2:-stable}
	# The download + install can take longer than the LuCI RPC/XHR timeout, so
	# run it in the background, write the result to a status file, and let the
	# page poll 'update.sh status'. A second install over a running one is not
	# started (both would write the same result file).
	if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
		echo '{"started":true,"already":true}'
		exit 0
	fi
	rm -f "$STATUS" "$STATUS.tmp"
	# Create the progress file right away so the page can poll it (the script
	# binary itself is replaced during the update).
	echo '{"running":true}' > "$STATUS"
	echo '{"started":true}'
	(
		do_install() {
			PM=$(pkgman)
			[ -n "$PM" ] || { echo '{"success":false,"error":"No package manager found"}'; return; }
			case "$PM" in apk) EXT=apk ;; opkg) EXT=ipk ;; esac
			# Beta releases are built from pre-release tags only (their assets
			# then differ in build number, not version). Fall back to stable when
			# no beta is published yet.
			TAG="" RELJSON=""
			if [ "$STAGE" = "beta" ]; then
				TAG=$(latest_beta)
				RELJSON=$(release_json "$TAG")
			elif [ "$STAGE" = "current" ]; then
				# Reinstall the exact release whose tag is on record as the
				# installed one - scanning the release list would be ambiguous
				# for a prerelease of the same base version as a stable release.
				TAG=$(cat "$TAGSTATE" 2>/dev/null)
				if [ -z "$TAG" ]; then
					echo '{"success":false,"error":"unknown_current_release"}'
					return
				fi
				RELJSON=$(release_json "$TAG")
				if [ -z "$RELJSON" ]; then
					echo '{"success":false,"error":"Could not reach GitHub"}'
					return
				fi
			fi
			if [ -z "$RELJSON" ]; then
				STAGE=stable
				RELJSON=$(api_json)
			fi
			# Full tag of the release we are about to install - recorded in
			# TAGSTATE so later prereleases of the same base version are offered.
			TAGG=""
			[ -n "$TAG" ] && TAGG="$TAG"
			[ -z "$TAGG" ] && TAGG=$(printf '%s' "$RELJSON" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
			if [ -z "$RELJSON" ]; then
				echo '{"success":false,"error":"Could not reach GitHub"}'; return
			fi
			if [ -z "$TAGG" ]; then
				# /releases/latest answers 404 (a non-empty body without a tag)
				# while GitHub has only prereleases. No stable release yet.
				echo '{"success":false,"error":"No stable release published yet"}'; return
			fi
			# Base version of the target tag (drops any -beta.N suffix) - used
			# below to tell a real success from an asset built with the version
			# that is already installed.
			TVAL=$(printf '%s' "$TAG" | sed -n 's/^v\([0-9][0-9.]*\).*/\1/p')
			if [ -z "$TVAL" ]; then
				TVAL=$(printf '%s' "$RELJSON" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([0-9][0-9.]*\).*/\1/p' | head -n1)
			fi
			PREV=$(installed_version "$PM")
			INSTALLED=""
			for BASE in "$PKG" "$I18N"; do
				URL=$(asset_url_in "$RELJSON" "$BASE" "$EXT")
				if [ -z "$URL" ]; then
					# The ru translation may not exist for this release - only
					# the main app package is mandatory.
					[ "$BASE" = "$I18N" ] && continue
					# Tag published but CI hasn't built the asset yet.
					echo '{"success":false,"error":"asset_pending"}'; return
				fi
				F="$TMP/$BASE.$EXT"
				rm -f "$F"
				if ! net_fetch 90 "$URL" "$F"; then
					echo '{"success":false,"error":"Download failed for '"$BASE"'"}'; return
				fi
				# Version from the asset FILE NAME (…-2.5.5-r1.apk, …_2.5.5-r1_all.ipk)
				# to tell a real failure from a non-zero exit when the package
				# actually landed.
				_want=$(basename "$URL" | sed -n 's/^.*[-_]\([0-9][0-9.]*\)-r[0-9][0-9]*[._].*$/\1/p')
				if [ "$PM" = apk ]; then
					apk add --allow-untrusted "$F" >/dev/null 2>&1; _rc=$?
				else
					opkg install --force-reinstall "$F" >/dev/null 2>&1; _rc=$?
				fi
				if [ "$_rc" != 0 ]; then
					if [ -n "$_want" ] && [ "$(installed_version "$PM")" = "$_want" ]; then
						logger -t h5000m-fancontrol "update: $PM returned $_rc, but $BASE $_want is installed - treating as success"
					elif [ "$BASE" = "$I18N" ]; then
						logger -t h5000m-fancontrol "update: ru translation install failed (non-fatal): $_rc"
					else
						rm -f "$F"; echo '{"success":false,"error":"Install failed for '"$BASE"'"}'; return
					fi
				fi
				rm -f "$F"
				INSTALLED="$INSTALLED $BASE"
			done
			# Drop LuCI's cached indexes/modules so the new bundle is served.
			rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null
			CUR=$(installed_version "$PM")
			# Verify the version actually changed; opkg/apk return 0 even when a
			# release asset was built with the already-installed version. Compare
			# against the version of the tag we actually installed, so a beta
			# build of the current stable version is not misreported either.
			if [ -n "$PREV" ] && [ "$CUR" = "$PREV" ]; then
				if [ -n "$TVAL" ] && [ "$TVAL" = "$CUR" ]; then
					printf '{"success":true,"installed":"%s","current":"%s","reinstalled":1,"stage":"%s"}\n' \
						"$(json_esc "$(echo $INSTALLED)")" "$(json_esc "$CUR")" "$STAGE"
					[ -n "$TAGG" ] && printf '%s\n' "$TAGG" > "$TAGSTATE"
					return
				fi
				printf '{"success":false,"current":"%s","error":"Reinstalled but version stayed %s - the release asset looks mispackaged (rebuild/reupload it)"}\n' "$(json_esc "$CUR")" "$(json_esc "$CUR")"
			else
				printf '{"success":true,"installed":"%s","current":"%s","stage":"%s"}\n' "$(json_esc "$(echo $INSTALLED)")" "$(json_esc "$CUR")" "$STAGE"
				[ -n "$TAGG" ] && printf '%s\n' "$TAGG" > "$TAGSTATE"
			fi
		}
		# Write to a temp file and move into place only when done, so status can
		# tell "running" (no final file yet) from "finished". The lock holds the
		# subshell PID ($$ would be the parent, which already exited).
		read -r _upid _ < /proc/self/stat 2>/dev/null
		echo "$_upid" > "$LOCK" 2>/dev/null
		do_install > "$STATUS.tmp" 2>/dev/null
		mv "$STATUS.tmp" "$STATUS"
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
	else
		echo '{"running":true}'
	fi
	;;

version)
	printf '{"installed":"%s","pm":"%s"}\n' "$(json_esc "$(installed_version "$(pkgman)")")" "$(pkgman)"
	;;

*)
	echo '{"success":false,"error":"usage: update.sh check [beta]|install [stable|beta]|status|version"}'
	exit 1
	;;
esac