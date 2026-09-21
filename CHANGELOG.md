# Changelog

🇬🇧 **English** | [🇷🇺 Русский](CHANGELOG.ru.md) | [🇨🇳 简体中文](CHANGELOG.zh-CN.md)

## 2.3.1

- The daemon now reads the 5G modem temperature published by the stock 5gmodem stack 
  (`/tmp/5gmodem_metrics_*.json`, `/tmp/5gmodem_stats/temp.*`, `/tmp/5gmodem_temp_*`). This replaces the legacy
  MTK temperature cache for devices such as the H5000M with a Fibocom FM350-GL, which do not provide
  /var/run/mt5700m/temperature.
- The modem temperature card in LuCI now shows the modem model (e.g. "Fibocom FM350-GL") next to the
  temperature instead of a generic hint.

- Redesigned the LuCI fan-curve page: the curve editor now has an interactive
  canvas chart that plots the fan curve and the firmware floor map against
  temperature, plus a marker for the current temperature with the requested
  and applied PWM, the hysteresis band and a colour legend. The chart animates
  smoothly, follows dark/light LuCI themes and becomes a stacked layout on
  narrow screens.
- The temperature card now tags the sensor that is currently driving the fan
  speed with a "Priority" badge.
- The page title now shows the installed app version inline next to the title
  (e.g. "Cooling management v2.3.1").
- Fixed manual-control saves so the slider value is always picked up when the
  form is submitted.
- The daemon now reports the kernel emergency floors as floor-map steps even
  when the firmware cooling maps are missing (patched device tree) or
  unreadable (minimal busybox), and builds `kernel_floor_levels` without
  trailing commas in edge cases.
- Release automation: `scripts/release.sh` cuts stable (`vX.Y.Z` from `main`)
  and beta (`vX.Y.Z-beta.N` from `beta`) tags; the release workflow checks the
  tag against `PKG_VERSION`, publishes `-beta.N` tags as GitHub prereleases and
  refuses tags whose commit is not on the matching branch. Full guide:
  `docs/RELEASING.md`.
- GitHub Actions release builds now cache the OpenWrt SDK archive (keyed on its
  sha256), so the multi-hundred-MB SDK is no longer downloaded on every run.
- Built-in self-update from the LuCI page: the new "Update" tab checks GitHub
  Releases for the latest stable version and installs it on the router
  (`.apk`/`.ipk` chosen by the package manager). The download and install run
  in the background with a progress indicator; the application package and,
  when published, the Russian translation (`luci-i18n-h5000m-fancontrol-ru`)
  are installed together.
- The updater checks GitHub releases over the router's regular internet
  connection (no proxy). By default
  only stable releases are offered - `-beta.N` prereleases can be opted into
  with the "Offer beta releases" checkbox, which also shows a warning that
  beta builds may be unstable and are not recommended for daily use.
- Update-check failures are now explained in the interface language: when the
  updater cannot reach GitHub, the page says it could not check for updates and
  asks to verify the router's internet access.
- The version poll is now reliable for repositories with no stable release: it
  no longer reports "Could not reach GitHub" when GitHub only hosts prereleases,
  and a new prerelease of the same base version (e.g. v2.3.1-beta.6 published
  after beta.5) is now offered, because prerelease tags are compared against the
  last installed tag instead of the package version. Prerelease detection also
  matches GitHub's compact JSON (`"prerelease":true`).
- A "Reinstall current version" button re-installs the exact release that is
  on record as installed (local tag file), which comes in handy after a broken
  or partial install. It works for both stable and beta releases.
- The version shown in the page header and on the "Update" tab now includes the
  beta suffix when a prerelease is installed (e.g. "v2.3.1-beta.7"), since the
  package manager cannot tell a stable from a prerelease build of the same
  package version.
- After a successful update the browser re-fetches the new page scripts and
  the session is ended once (a single re-login), so the updated interface and
  RPC permissions take effect immediately.
- Update logic lives in `/usr/share/h5000m-fancontrol/update.sh`
  (`check`, `install`, `status`, `version`); the LuCI user can run it via the
  application's RPC ACL.
- Documentation (README and changelog) is maintained in English, Russian and
  Simplified Chinese, and the Chinese UI translation is kept in sync with the
  new strings.

## 2.3.0

- The status output now reports the firmware fan map (`kernel_floor_levels`,
  e.g. `40=128,85=192,115=255`) and the LuCI page shows the exact
  thresholds instead of only a generic "kernel safety floor" note.
- Added an experimental `override_floor` option (schema v4, off by default)
  that lets automatic and manual output run below the stock firmware fan
  map; kernel trip enforcement and failsafe behaviour are preserved.
- Documented the stock 40/85/115 °C fan map and the patch-based fix.
- Translation packages are pinned to the application version instead of the
  po-mtime/git revision that `luci.mk` derives in SDK builds.
- `build-release.sh` now discovers the languages in `po/` automatically and
  collects every built `luci-app-*` / `luci-i18n-h5000m-fancontrol-*`
  package, so adding a translation needs no script changes.

## 2.2.1

- Fixed release packaging: the GitHub Actions build now compiles and ships the
  `luci-i18n-h5000m-fancontrol-ru` translation package (`.lmo` catalogs are not
  part of the main app package), and documents installing it for the Russian UI.

## 2.2.0

- Retuned the silent fan curve to `20:0,35:0,40:20,50:20,60:40,70:50,85:100,95:100`.
- Added a schema v3 migration that replaces only the untouched default silent curve.
- Added a Russian LuCI translation.
- CI now validates all translation catalogs and runs the thermal policy safety regression test.

## 2.1.0

- The fan controller no longer switches the entire CPU thermal zone to `user_space`.
- Automatically restores the thermal policy left behind by older versions while
  preserving CPU throttling and overheat protection.
- Status reads and control writes now use separate RPC privileges.
- Declared the UCI configuration file to be kept across upgrades.

## 2.0.2

- Read the timestamped temperature cache provided by the MT5700M manager.
- Ignore stale module temperatures older than 60 s while staying compatible
  with the legacy QModem cache.

## 2.0.1

- Unified the GitHub Release and OpenWrt package versioning rules.
- Collected post-2.0.0 build compatibility and delivery revisions.

## 2.0.0

- Redesigned the end-user LuCI thermal management page.
- Added temperature aggregation for the CPU, Ethernet PHY, Wi-Fi and the 5G module.
- Added silent, balanced, performance and custom fan curves.
- Added temperature hysteresis, delayed spin-down and start boost.
- Added sensor failsafe and a high-temperature userspace safety floor.
- Added an optional H5000M device-tree patch to stop the kernel and userspace
  from competing over PWM.

---

*The English changelog is canonical; other languages are translations kept in sync manually.*
