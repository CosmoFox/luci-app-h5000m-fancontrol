# Changelog

🇬🇧 **English** | [🇷🇺 Русский](CHANGELOG.ru.md) | [🇨🇳 简体中文](CHANGELOG.zh-CN.md)

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
