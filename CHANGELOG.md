# Changelog

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

- 风扇控制器不再把完整 CPU thermal zone 切换到 `user_space`。
- 自动恢复旧版本遗留的 thermal policy，并保留 CPU 降频和高温保护。
- 状态读取与控制写入使用独立 RPC 权限。
- 将 UCI 配置声明为升级保留文件。

## 2.0.2

- 读取 MT5700M 管理器提供的带时间戳温度缓存。
- 忽略超过 60 秒的陈旧模组温度，并兼容旧 QModem 缓存。

## 2.0.1

- 统一 GitHub Release 与 OpenWrt 软件包版本规则。
- 汇总 2.0.0 后的构建兼容性与交付修订。

## 2.0.0

- 重新设计面向最终用户的 LuCI 散热管理界面
- 增加 CPU、以太网 PHY、Wi-Fi 和 5G 模块温度汇总
- 增加静音、均衡、性能及自定义风扇曲线
- 增加温度滞回、降速延迟和启动助推
- 增加传感器故障保护及高温用户空间安全下限
- 增加可选 H5000M 设备树补丁，避免内核与用户空间争用 PWM
