# H5000M Fan Control

[![CI](https://github.com/CosmoFox/luci-app-h5000m-fancontrol/actions/workflows/ci.yml/badge.svg)](https://github.com/CosmoFox/luci-app-h5000m-fancontrol/actions/workflows/ci.yml)
[![Build Release](https://github.com/CosmoFox/luci-app-h5000m-fancontrol/actions/workflows/release.yml/badge.svg)](https://github.com/CosmoFox/luci-app-h5000m-fancontrol/actions/workflows/release.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

us **English** | [🇷🇺 Русский](#ru) | [🇨🇳 简体中文](#zh) | [🇩🇪 Deutsch](#de)

*The English text is canonical; the Russian and Chinese versions are collapsed below.*

An OpenWrt LuCI fan manager for the Hiveton H5000M: temperature monitoring, automatic fan curves, manual PWM, start boost, temperature hysteresis, delayed spin-down and sensor-fault failsafe — while the kernel's CPU throttling, hot and critical overheat protections remain intact.

Versions follow the standard `major.minor.patch-rREVISION` format. GitHub Release tags use the semantic version only (currently `v2.3.0`); the OpenWrt package version is `2.3.1-r1`.

![Fan control UI](docs/fan-control-ui.png)

## Features

- Aggregates fresh cached temperatures from the CPU, Ethernet PHY, Wi-Fi radios and the MT5700M module manager or luci-app-5gmodem telemetry; modem throttling levels (1/2/3) reported by luci-app-5gmodem raise the fan output to at least 50%/75%/100%
- Four automatic curves: Silent, Balanced, Performance and Custom
- Three run modes: automatic, manual PWM and kernel-protection-only
- Temperature hysteresis and delayed spin-down to reduce frequent fan fluttering
- Start boost after the fan has stopped
- Automatic high-output failsafe mode on sensor or curve faults
- Simplified Chinese, German and Russian LuCI interface (language follows LuCI settings automatically)
- In-app self-update: offers the latest stable GitHub release from the LuCI page (optional `-beta.N` prereleases with a beta warning; the Russian interface package is installed along with the app)
- No cloud dependency; no device data is collected or uploaded

## Compatibility

- Hiveton H5000M
- OpenWrt SNAPSHOT (LuCI JavaScript views)
- `pwm-fan` driver and `/sys/class/hwmon/*/pwm1` control node

This project is designed for the H5000M device tree and sensor layout. Even if other devices can install the package, they are not supported.

## Release channels

- Stable: tag `vX.Y.Z` on `main` → regular GitHub Release.
- Beta: tag `vX.Y.Z-beta.N` on `beta` → GitHub prerelease with `beta` in the name.

CI checks the tag against `PKG_VERSION` in the Makefile and that the tagged commit is contained in the matching branch. Use `scripts/release.sh v2.4.0-beta.1` to cut a release from a clean, up-to-date branch. Full guide: [docs/RELEASING.md](docs/RELEASING.md).

## Integrating into OpenWrt sources

Run from the OpenWrt source root:

```sh
git clone https://github.com/FAN789/luci-app-h5000m-fancontrol.git \
  package/luci-app-h5000m-fancontrol

make menuconfig
# LuCI -> Applications -> luci-app-h5000m-fancontrol

make package/luci-app-h5000m-fancontrol/compile V=s
```

Prebuilt `.apk` files in GitHub Releases are compiled by GitHub Actions with the official OpenWrt 25.12.6 `mediatek/filogic` SDK and target 25.12.x builds with the same ABI. Each release also ships the build public key and SHA256 checksums. Since the fan safety policy depends on the device tree, integrating this project into your firmware — and evaluating the patch below — is recommended over installing the package alone.

UI translations ship as separate packages: install the matching `luci-i18n-h5000m-fancontrol-ru` / `-de` / `-zh-cn` package from the release assets alongside the main `.apk` to enable Russian, German or Simplified Chinese.

## Exclusive fan control

The active cooling mapping in the stock H5000M device tree modifies PWM in parallel with the userspace controller. To let the automatic curves fully control the fan, apply the included patch before building the firmware:

```sh
git apply package/luci-app-h5000m-fancontrol/openwrt-patches/h5000m-userspace-fan-control.patch
```

The patch removes only the three H5000M fan cooling-maps; the CPU throttling, hot and critical trip points are preserved. The controller also forces higher fan output when the CPU reaches its high-temperature threshold.

Without the patch the plugin still runs, but the kernel thermal governor may raise the actual PWM, so the requested output and the real fan output shown in the UI can differ.

## Stock firmware fan map (why the fan stays ≥ 50%)

Without the device-tree patch the kernel still co-owns the fan. The stock H5000M cooling map holds PWM at 128 (≈50 %) from 40 °C, 192 (≈75 %) from 85 °C and 255 from 115 °C, so every profile — including Quiet — is clamped by the "kernel safety floor". The LuCI page shows the real thresholds read from the device tree.

Recommended: build firmware with `openwrt-patches/h5000m-userspace-fan-control.patch`. Experimental alternative: enable "Ignore firmware fan map" in the plugin settings to let the curve run below the firmware levels. The kernel rewrites its own level whenever a trip boundary is crossed, so expect a brief jump at 40/85/115 °C; hot/critical CPU protection is unaffected.

## Modem telemetry validation

The optional `/tmp/5gmodem/tele.json` source (luci-app-5gmodem telemetry) is
parsed without extra dependencies. Only a single complete flat JSON object is
accepted; top-level numeric integer fields are used: `temp` in -40–150 °C and
`therm` in 0–3. Strings, booleans, null, fractional or out-of-range values,
truncated documents and trailing garbage supply no readings; files older than
90 s or dated in the future are ignored. Temperature priority: MT5700M cache
→ 5gmodem telemetry → QModem cache. Throttling levels 1/2/3
set a minimum PWM of 128/192/255 only while the app controls the fan; the
kernel cooling floor still wins when it is higher.

## Self-update

The management page has an "Update" tab that offers the latest **stable**
GitHub release of this app (`releases/latest`). An optional "Offer beta
releases" checkbox lists `-beta.N` prereleases with an "Install beta" button
and a warning that beta builds may be unstable and are not recommended for
daily use. "Check for updates" compares the installed version with the latest
release; "Install update" downloads the application package and, when
published, the Russian interface (`luci-i18n-h5000m-fancontrol-ru`) for the
router's package manager (`.apk` on SNAPSHOT/apk, `.ipk` on opkg) and installs
them in the background with a progress indicator.

The updater checks GitHub releases over the router's regular internet
connection (no proxy). After a successful update the page reloads and you sign in again, so the updated interface and RPC permissions
apply immediately. Only release assets from this repository are downloaded —
no device data is uploaded.

## Configuration & services

- UCI configuration: `/etc/config/h5000m_fancontrol`
- procd service: `/etc/init.d/h5000m-fancontrol`
- Controller: `/usr/sbin/h5000m-fancontrol`
- Updater script: `/usr/share/h5000m-fancontrol/update.sh`
- LuCI page: System → Fan Control

Common commands:

```sh
/usr/sbin/h5000m-fancontrol status
/usr/sbin/h5000m-fancontrol apply
/etc/init.d/h5000m-fancontrol restart
```

## Testing

- `tests/test-*.sh` — POSIX shell regression tests for the controller, updater and helpers; run all with `for t in tests/test-*.sh; do sh "$t"; done` (the CI `static-checks` job runs the same set plus ShellCheck):
  - `test-lib.sh` — unit tests for the `lib.sh` helpers (curve math, temperature parsing, cache/metrics parsers);
  - `test-config-load.sh` — config load and sanitization in the controller (with a stub `uci`);
  - `test-module-temperature.sh` — MT5700M modem temperature from the file cache;
  - `test-vendor-temperature.sh` — vendor radio temperature via `iwpriv` (functions only, never touches the fan);
  - `test-thermal-policy-safety.sh` — safety invariants: the controller must not move the CPU thermal zone to `user_space` and must release control;
  - `test-uci-defaults.sh` — the `uci-defaults` migration scripts (91/92/93) on an isolated store;
  - `test-update.sh` — unit tests for the `update.sh` helpers (versions, assets, languages, JSON escaping, apk error parsing) plus CLI smoke.
- `tests/ui/states-test.mjs` — visual test of the LuCI page in failure states: no temperature source, modem absent, no Wi-Fi radio, kernel-owned thermal policy, failsafe, stale status, active speed-down delay, manual mode. It temporarily swaps the router's status script (`/usr/sbin/h5000m-fancontrol-status`) for a stub printing the crafted `key=value` payload, waits for the expected state, screenshots the rendered page and restores the original binary (md5-verified); the daemon keeps controlling the fan for real throughout. Output: `preview/ui-states/report.html`. Run:

  ```sh
  cd tests/ui && npm install
  H5FAN_PASS=<LuCI password> node states-test.mjs
  ```

  Details and scenario format: `tests/ui/README.md`.

## Safety notes

Fan control is a device-safety function. Keep an eye on temperatures after changing a custom curve or manual PWM. The controller only manages fan PWM and never switches the entire CPU thermal zone to `user_space`; regardless of whether the exclusive fan patch is applied, the CPU throttling, hot and critical protections in the device tree must not be removed.

## License

[Apache License 2.0](LICENSE)

<a id="ru"></a>

<details>
<summary><b>🇷🇺 Русский</b></summary>

# H5000M Fan Control

Менеджер вентилятора для OpenWrt/LuCI на Hiveton H5000M: мониторинг температур, автоматические кривые охлаждения, ручное управление PWM, стартовый буст, температурный гистерезис, задержка остановки и аварийная защита при отказе датчиков — при сохранении ядерных механизмов троттлинга CPU, а также защит hot и critical.

Версии следуют формату `мажор.минор.патч-rРЕВИЗИЯ`. Теги GitHub Release используют только семантическую версию (сейчас `v2.3.0`), версия пакета OpenWrt — `2.3.1-r1`.

![Страница управления вентилятором](docs/fan-control-ui.png)

## Возможности

- Агрегация свежих кэшированных температур CPU, Ethernet PHY, радиомодулей Wi-Fi и менеджера модуля MT5700M или телеметрии luci-app-5gmodem; уровни троттлинга модема (1/2/3) из luci-app-5gmodem поднимают выход вентилятора минимум до 50 %/75 %/100 %
- Четыре автоматические кривые: «Тихая», «Сбалансированная», «Производительная» и произвольная
- Три режима работы: автоматический, ручной PWM и только защита ядра
- Температурный гистерезис и задержка остановки — меньше частых перепадов оборотов
- Стартовый буст после полной остановки вентилятора
- Автоматический переход в режим высокой мощности при неисправности датчика или кривой
- Интерфейс LuCI на русском, немецком и упрощённом китайском (язык следует настройкам LuCI)
- Встроенное самообновление: вкладка LuCI предлагает последний стабильный релиз на GitHub (опционально пре-релизы `-beta.N` с предупреждением; вместе с приложением ставится русский интерфейс)
- Без облачных сервисов; данные устройства не собираются и никуда не отправляются

## Совместимость

- Hiveton H5000M
- OpenWrt SNAPSHOT (LuCI JavaScript views)
- драйвер `pwm-fan` и узел управления `/sys/class/hwmon/*/pwm1`

Проект рассчитан на device tree и расположение датчиков H5000M. На других устройствах использование не рекомендуется, даже если пакет устанавливается.

## Каналы релизов

- Стабильный: тег `vX.Y.Z` в `main` → обычный релиз GitHub.
- Бета: тег `vX.Y.Z-beta.N` в ветке `beta` → пре-релиз GitHub с `beta` в названии.

CI сверяет тег с `PKG_VERSION` в Makefile и проверяет, что помеченный коммит входит в соответствующую ветку. Выпуск — через `scripts/release.sh v2.4.0-beta.1` из чистого актуального дерева. Полное руководство: [docs/RELEASING.md](docs/RELEASING.md).

## Интеграция в исходники OpenWrt

В корне исходников OpenWrt:

```sh
git clone https://github.com/FAN789/luci-app-h5000m-fancontrol.git \
  package/luci-app-h5000m-fancontrol

make menuconfig
# LuCI -> Applications -> luci-app-h5000m-fancontrol

make package/luci-app-h5000m-fancontrol/compile V=s
```

Готовые `.apk` в GitHub Releases собираются GitHub Actions в официальном SDK `mediatek/filogic` от OpenWrt 25.12.6 и подходят для сборок 25.12.x с тем же ABI. Каждый релиз также содержит публичный ключ сборки и контрольные суммы SHA256. Поскольку безопасная стратегия вентилятора зависит от device tree, проект рекомендуется интегрировать в прошивку и одновременно оценить патч ниже, а не устанавливать только пакет.

Пакеты переводов интерфейса выносятся отдельно: установите `luci-i18n-h5000m-fancontrol-ru`, `-de` или `-zh-cn` из ассетов релиза вместе с основным `.apk`, чтобы включить русский, немецкий или упрощённый китайский интерфейс.

## Исключительный контроль вентилятора

Активное охлаждение в штатном device tree H5000M изменяет PWM параллельно с пользовательским контроллером. Чтобы кривая полностью управляла вентилятором, примените патч до сборки прошивки:

```sh
git apply package/luci-app-h5000m-fancontrol/openwrt-patches/h5000m-userspace-fan-control.patch
```

Патч удаляет только три fan cooling-map H5000M; троттлинг CPU и пороги hot/critical сохраняются. Контроллер также принудительно повышает мощность вентилятора при достижении CPU порога высокой температуры.

Без патча плагин тоже работает, но thermal governor ядра может поднимать фактический PWM, поэтому запрошенная и реальная мощность на странице LuCI могут различаться.

## Штатная карта вентилятора прошивки (почему вентилятор держится ≥ 50 %)

Без патча device tree ядро продолжает делить управление вентилятором с userspace. Штатная cooling map H5000M удерживает PWM на уровне 128 (≈50 %) с 40 °C, 192 (≈75 %) с 85 °C и 255 с 115 °C, поэтому любой профиль — включая «Тихий» — ограничен «ядерным безопасным порогом». Страница LuCI показывает фактические пороги, прочитанные из device tree.

Рекомендуется: собрать прошивку с `openwrt-patches/h5000m-userspace-fan-control.patch`. Экспериментальная альтернатива: включить «Игнорировать карту вентилятора прошивки» в настройках плагина, чтобы кривая могла работать ниже уровней прошивки. Ядро перезаписывает свой уровень при пересечении порога срабатывания, поэтому ожидайте кратковременный скачок при 40/85/115 °C; защита CPU hot/critical не затрагивается.

## Проверка телеметрии модема

Опциональный источник `/tmp/5gmodem/tele.json` (телеметрия luci-app-5gmodem)
разбирается без дополнительных зависимостей. Принимается только один полный
плоский JSON-объект; используются числовые целочисленные поля верхнего
уровня: `temp` в диапазоне −40…150 °C и `therm` 0–3. Строки, булевы значения,
null, дробные и вне диапазона значения, оборванные документы и мусор после
объекта не дают показаний; файлы старше 90 с или с датой в будущем
игнорируются. Приоритет температуры: кэш MT5700M → телеметрия 5gmodem → кэш
QModem. Уровни троттлинга 1/2/3 задают минимум PWM
128/192/255 только пока приложение управляет вентилятором; более высокий
порог ядра по-прежнему имеет приоритет.

## Самообновление

На странице управления есть вкладка «Обновление», которая предлагает
последний **стабильный** релиз этого приложения на GitHub
(`releases/latest`). Опция «Предлагать бета-релизы» показывает пре-релизы
`-beta.N` с кнопкой «Установить бета-версию» и предупреждением, что такие
сборки могут быть нестабильны и не рекомендуются для повседневного
использования. «Проверить обновления» сравнивает установленную версию с
последним релизом;
«Установить обновление» скачивает пакет приложения и, если он опубликован,
русский интерфейс (`luci-i18n-h5000m-fancontrol-ru`) под пакетный менеджер
роутера (`.apk` на SNAPSHOT/apk, `.ipk` на opkg) и устанавливает их в фоне
с индикатором прогресса.

Обновление обращается к GitHub через штатное интернет-соединение роутера
(без прокси). После успешного обновления страница перезагружается, и вы входите заново, чтобы обновлённый
интерфейс и новые RPC-права применились сразу. Скачиваются только ассеты
релизов этого репозитория — данные устройства никуда не отправляются.

## Конфигурация и сервисы

- Конфигурация UCI: `/etc/config/h5000m_fancontrol`
- Сервис procd: `/etc/init.d/h5000m-fancontrol`
- Контроллер: `/usr/sbin/h5000m-fancontrol`
- Скрипт обновления: `/usr/share/h5000m-fancontrol/update.sh`
- Страница LuCI: System → Fan Control

Типичные команды:

```sh
/usr/sbin/h5000m-fancontrol status
/usr/sbin/h5000m-fancontrol apply
/etc/init.d/h5000m-fancontrol restart
```

## Тестирование

- `tests/test-*.sh` — регрессионные shell-тесты контроллера, апдейтера и хелперов; весь набор: `for t in tests/test-*.sh; do sh "$t"; done` (в CI job `static-checks` прогоняется тот же набор плюс ShellCheck):
  - `test-lib.sh` — юнит-тесты хелперов `lib.sh` (математика кривой, парсинг температур, парсеры кеша и метрик);
  - `test-config-load.sh` — загрузка и санитизация конфигурации контроллером (с подменным `uci`);
  - `test-module-temperature.sh` — температура модуля MT5700M из файлового кеша;
  - `test-vendor-temperature.sh` — температура радио через `iwpriv` (только функции, вентилятор не трогает);
  - `test-thermal-policy-safety.sh` — инварианты безопасности: контроллер не переводит thermal-зону CPU в `user_space` и обязан отпускать управление;
  - `test-uci-defaults.sh` — миграционные скрипты `uci-defaults` (91/92/93) на изолированном сторе;
  - `test-update.sh` — юнит-тесты хелперов `update.sh` (версии, ассеты, языки, экранирование JSON, разбор ошибок apk) плюс CLI-smoke.
- `tests/ui/states-test.mjs` — визуальная проверка страницы LuCI в состояниях отказа: нет источника температуры, модем отсутствует, нет модуля Wi-Fi, политику держит ядро, failsafe, устаревший статус, активная задержка снижения оборотов, ручной режим. Скрипт временно подменяет статус-скрипт на роутере (`/usr/sbin/h5000m-fancontrol-status`) заглушкой с нужным набором `key=value`, дожидается ожидаемого состояния, снимает скриншоты страницы и восстанавливает оригинал (сверка md5); демон при этом продолжает реально управлять вентилятором. Результат: `preview/ui-states/report.html`. Запуск:

  ```sh
  cd tests/ui && npm install
  H5FAN_PASS=<пароль LuCI> node states-test.mjs
  ```

  Подробности и формат сценариев: `tests/ui/README.md`.

## Примечания по безопасности

Управление вентилятором — функция безопасности устройства. После изменения произвольной кривой или ручного PWM постоянно контролируйте температуры. Контроллер управляет только PWM вентилятора и никогда не переводит всю thermal-зону CPU в `user_space`; независимо от применения патча из device tree нельзя удалять троттлинг CPU и защиты hot и critical.

## Лицензия

[Apache License 2.0](LICENSE)

</details>

<a id="zh"></a>

<details>
<summary><b>🇨🇳 简体中文</b></summary>

# H5000M 风扇控制

面向 Hiveton H5000M 的 OpenWrt LuCI 风扇管理器。提供温度监控、自动风扇曲线、手动 PWM、启停助推、温度滞回、降速延迟和传感器故障保护，并保留内核的 CPU 降频、高温及临界过热保护。

版本采用标准的 `主版本.次版本.修订版本-r打包修订` 格式。GitHub Release 仅使用语义版本标签（当前为 `v2.3.0`），OpenWrt 安装包版本为 `2.3.1-r1`。

![散热管理界面](docs/fan-control-ui.png)

## 功能

- 汇总 CPU、以太网 PHY、Wi-Fi 射频及 MT5700M 管理器或 luci-app-5gmodem 遥测提供的新鲜缓存温度；luci-app-5gmodem 报告的模组降频等级（1/2/3）会把风扇输出至少提高到 50%/75%/100%
- 静音、均衡、性能和自定义四种自动曲线
- 自动、手动和仅内核保护三种运行模式
- 温度滞回及降速延迟，减少风扇频繁波动
- 风扇停转后的启动助推
- 传感器或曲线异常时自动进入高输出安全模式
- 简体中文、德语和俄语 LuCI 界面（语言跟随 LuCI 设置自动切换）
- 应用内自更新：通过 LuCI 页面提供 GitHub 最新稳定版（可选 `-beta.N` 预发布版并显示测试版警告；俄语界面包随应用一并安装）
- 不依赖云服务，不收集或上传设备数据

## 兼容性

- Hiveton H5000M
- OpenWrt SNAPSHOT（基于 LuCI JavaScript 视图）
- `pwm-fan` 驱动及 `/sys/class/hwmon/*/pwm1` 控制节点

本项目针对 H5000M 的设备树和传感器布局设计。其他设备即使能够安装，也不建议直接使用。

## 发布渠道

- 稳定版：在 `main` 上打 `vX.Y.Z` 标签 → 普通 GitHub Release。
- 测试版：在 `beta` 分支上打 `vX.Y.Z-beta.N` 标签 → GitHub 预发布版本，名称中包含 `beta`。

CI 会将标签与 Makefile 中的 `PKG_VERSION` 比对，并检查被标记的提交包含在对应分支中。发布请使用 `scripts/release.sh v2.4.0-beta.1`（要求工作区干净且分支已同步）。完整指南见 [docs/RELEASING.md](docs/RELEASING.md)。

## 集成到 OpenWrt 源码

在 OpenWrt 源码根目录执行：

```sh
git clone https://github.com/FAN789/luci-app-h5000m-fancontrol.git \
  package/luci-app-h5000m-fancontrol

make menuconfig
# LuCI -> Applications -> luci-app-h5000m-fancontrol

make package/luci-app-h5000m-fancontrol/compile V=s
```

GitHub Releases 中的预编译 `.apk` 由 GitHub Actions 使用官方 OpenWrt 25.12.6 `mediatek/filogic` SDK 构建，适用于同一 ABI 的 25.12.x 版本。Release 同时提供构建公钥和 SHA256 校验文件。由于风扇安全策略依赖设备树，建议把本项目集成进固件并同时评估下方补丁，而不是只安装软件包。

界面语言包以独立软件包发布：从 Release 资源中安装与主 `.apk` 配套的 `luci-i18n-h5000m-fancontrol-ru` / `-de` / `-zh-cn` 包，即可启用俄语、德语或简体中文界面。

## 独占风扇策略控制

H5000M 原设备树中的主动散热映射会与用户空间控制器同时修改 PWM。若希望自动曲线完整控制风扇，请在编译固件前应用项目提供的补丁：

```sh
git apply package/luci-app-h5000m-fancontrol/openwrt-patches/h5000m-userspace-fan-control.patch
```

该补丁仅删除 H5000M 的三个风扇 cooling-map；CPU 降频、hot 和 critical 温控节点仍然保留。控制器还会在 CPU 达到高温阈值时强制提高风扇输出。

不应用补丁时插件仍可运行，但内核 thermal governor 可能提高实际 PWM，因此界面中的请求输出和实际输出可能不同。

## 出厂固件风扇映射（为什么风扇始终 ≥ 50%）

未应用设备树补丁时，内核仍然与用户空间共同控制风扇。H5000M 出厂 cooling map 会在 40 °C 时保持 PWM 128（≈50 %）、85 °C 时 192（≈75 %）、115 °C 时 255，因此包括静音在内的所有曲线都会被"内核安全下限"钳制。LuCI 页面显示的是从设备树读取的真实阈值。

推荐：使用 `openwrt-patches/h5000m-userspace-fan-control.patch` 编译固件。实验性替代方案：在插件设置中启用"忽略固件风扇映射"，让曲线可以低于固件水平运行。内核会在穿越 trip 阈值时重写自己的输出，因此在 40/85/115 °C 附近可能出现短暂跳变；CPU hot/critical 保护不受影响。

## 调制解调器遥测校验

可选的 `/tmp/5gmodem/tele.json` 数据源（luci-app-5gmodem 遥测）在没有任何额外依赖的情况下解析。仅接受单个完整的扁平 JSON 对象；仅使用顶层数值整数字段：`temp`（-40–150 °C）与 `therm`（0–3）。字符串、布尔值、null、小数或越界值、截断的文档以及尾随垃圾都不会提供读数；早于 90 秒或日期在未来的文件会被忽略。温度优先级：MT5700M 缓存 → 5gmodem 遥测 → QModem 缓存。降频等级 1/2/3 仅在应用控制风扇时将 PWM 下限设为 128/192/255；内核散热下限更高时仍然优先。

## 应用内更新

管理页面新增“更新”标签页，用于提供本应用在 GitHub 上最新的**稳定版**
发布（`releases/latest`）。勾选“提供测试版发布”即可列出 `-beta.N`
预发布版本，显示“安装测试版”按钮并给出警告——测试版可能不稳定，不建议
日常使用。点击“检查更新”
可将已安装版本与最新发布比对；当存在新版本时，“安装更新”会按路由器的
包管理器（SNAPSHOT/apk 使用 `.apk`，opkg 使用 `.ipk`）下载应用包，并在
已发布时一并下载俄语界面包（`luci-i18n-h5000m-fancontrol-ru`），随后在
后台安装并显示进度。

更新程序通过路由器的常规网络连接访问 GitHub（不使用代理）。更新成功后页面会刷新并需要
重新登录一次，以便新界面和 RPC 权限立即生效。仅下载本仓库的发布资源，
不向任何地方上传设备数据。

## 配置与服务

- UCI 配置：`/etc/config/h5000m_fancontrol`
- procd 服务：`/etc/init.d/h5000m-fancontrol`
- 控制器：`/usr/sbin/h5000m-fancontrol`
- 更新脚本：`/usr/share/h5000m-fancontrol/update.sh`
- LuCI 页面：系统 → 风扇控制

常用命令：

```sh
/usr/sbin/h5000m-fancontrol status
/usr/sbin/h5000m-fancontrol apply
/etc/init.d/h5000m-fancontrol restart
```

## 测试

- `tests/test-*.sh`：控制器、更新器和辅助函数的 POSIX shell 回归测试；全部运行：`for t in tests/test-*.sh; do sh "$t"; done`（CI 的 `static-checks` 任务运行同一组测试并附加 ShellCheck）：
  - `test-lib.sh` —— `lib.sh` 辅助函数的单元测试（曲线计算、温度解析、缓存/指标解析器）；
  - `test-config-load.sh` —— 控制器加载与净化配置（使用桩 `uci`）；
  - `test-module-temperature.sh` —— 从文件缓存读取 MT5700M 模块温度；
  - `test-vendor-temperature.sh` —— 通过 `iwpriv` 获取厂商射频温度（仅函数，不触碰风扇）；
  - `test-thermal-policy-safety.sh` —— 安全不变量：控制器不得将 CPU thermal zone 切换为 `user_space`，且必须释放控制；
  - `test-uci-defaults.sh` —— 在隔离存储上测试 `uci-defaults` 迁移脚本（91/92/93）；
  - `test-update.sh` —— `update.sh` 辅助函数的单元测试（版本、资产、语言、JSON 转义、apk 错误解析）及 CLI 冒烟测试。
- `tests/ui/states-test.mjs`：LuCI 页面故障状态的可视化测试：无温度源、无调制解调器、无 Wi-Fi 射频、内核持有散热策略、failsafe、状态过期、降速延迟生效、手动模式。脚本会临时把路由器上的状态脚本（`/usr/sbin/h5000m-fancontrol-status`）替换为输出指定 `key=value` 数据的桩脚本，等待预期状态出现，截取页面截图，并恢复原始脚本（校验 md5）；期间守护进程仍实际控制风扇。输出：`preview/ui-states/report.html`。运行：

  ```sh
  cd tests/ui && npm install
  H5FAN_PASS=<LuCI 密码> node states-test.mjs
  ```

  详见 `tests/ui/README.md`。

## 安全说明

风扇控制属于设备安全功能。修改自定义曲线或手动 PWM 后应持续观察温度。控制器只管理风扇 PWM，从不把整个 CPU thermal zone 切换到 `user_space`；无论是否应用独占风扇补丁，都不应删除设备树中的 CPU 降频、hot 或 critical 保护。

## 许可证

[Apache License 2.0](LICENSE)

</details>

<a id="de"></a>

<details>
<summary><b>🇩🇪 Deutsch</b></summary>

# H5000M Lüftersteuerung

Ein OpenWrt-LuCI-Lüfter-Manager für das Hiveton H5000M: Temperaturüberwachung, automatische Lüfterkurven, manuelles PWM, Start-Boost, Temperaturhysterese, verzögertes Herunterregeln und Sensor-Ausfallschutz — während CPU-Throttling sowie die Hot- und Critical-Überhitzungsschutzmechanismen des Kernels erhalten bleiben.

Die Versionen folgen dem üblichen Format `major.minor.patch-rREVISION`. GitHub-Release-Tags verwenden nur die semantische Version (aktuell `v2.3.0`); die OpenWrt-Paketversion ist `2.3.1-r1`.

![Lüftersteuerungs-Oberfläche](docs/fan-control-ui.png)

## Funktionen

- Bündelt aktuelle Cache-Temperaturen von CPU, Ethernet-PHY, Wi-Fi-Funkmodulen und dem MT5700M-Modul-Manager oder der luci-app-5gmodem-Telemetrie; vom Modem gemeldete Drosselstufen (1/2/3) heben die Lüfterausgabe auf mindestens 50 %/75 %/100 % an
- Vier automatische Kurven: Leise, Ausgewogen, Leistung und Benutzerdefiniert
- Drei Betriebsmodi: automatisch, manuelles PWM und nur Kernelschutz
- Temperaturhysterese und verzögertes Herunterregeln gegen häufiges Lüfterflattern
- Start-Boost, nachdem der Lüfter gestoppt wurde
- Automatischer Failsafe-Modus mit hoher Ausgabe bei Sensor- oder Kurvenfehlern
- Vereinfachtes Chinesisch, Deutsch und Russisch als LuCI-Oberfläche (Sprache folgt den LuCI-Einstellungen automatisch)
- In-App-Selbstupdate: bietet das neueste stabile GitHub-Release auf der LuCI-Seite an (optionale `-beta.N`-Vorabversionen mit Beta-Warnung; das russische Sprachpaket wird zusammen mit der App installiert)
- Keine Cloud-Abhängigkeit; es werden keine Gerätedaten erhoben oder hochgeladen

## Kompatibilität

- Hiveton H5000M
- OpenWrt SNAPSHOT (LuCI-JavaScript-Ansichten)
- `pwm-fan`-Treiber und Steuerknoten `/sys/class/hwmon/*/pwm1`

Dieses Projekt ist auf den Gerätebaum und das Sensorlayout des H5000M ausgelegt. Auch wenn das Paket auf anderen Geräten installierbar ist, werden diese nicht unterstützt.

## Release-Kanäle

- Stabil: Tag `vX.Y.Z` auf `main` → reguläres GitHub-Release.
- Beta: Tag `vX.Y.Z-beta.N` auf `beta` → GitHub-Vorabrelease mit `beta` im Namen.

Die CI prüft den Tag gegen `PKG_VERSION` im Makefile und ob der getaggte Commit im passenden Branch enthalten ist. Mit `scripts/release.sh v2.4.0-beta.1` erstellen Sie ein Release aus einem sauberen, aktuellen Branch. Vollständige Anleitung: [docs/RELEASING.md](docs/RELEASING.md).

## Einbindung in OpenWrt-Quellen

Vom OpenWrt-Quellverzeichnis ausführen:

```sh
git clone https://github.com/FAN789/luci-app-h5000m-fancontrol.git \
  package/luci-app-h5000m-fancontrol

make menuconfig
# LuCI -> Applications -> luci-app-h5000m-fancontrol

make package/luci-app-h5000m-fancontrol/compile V=s
```

Vorkompilierte `.apk`-Dateien in den GitHub-Releases werden von GitHub Actions mit dem offiziellen OpenWrt-25.12.6-SDK für `mediatek/filogic` erstellt und zielen auf 25.12.x-Builds mit derselben ABI. Jedes Release enthält außerdem den öffentlichen Build-Schlüssel und SHA256-Prüfsummen. Da die Lüftersicherheitsrichtlinie vom Gerätebaum abhängt, wird die Einbindung dieses Projekts in Ihre Firmware — einschließlich der Bewertung des folgenden Patches — empfohlen, statt nur das Paket zu installieren.

Oberflächenübersetzungen werden als eigene Pakete ausgeliefert: Installieren Sie das passende Paket `luci-i18n-h5000m-fancontrol-ru` / `-de` / `-zh-cn` aus den Release-Assets zusammen mit dem Haupt-`.apk`, um Russisch, Deutsch oder Vereinfachtes Chinesisch zu aktivieren.

## Exklusive Lüftersteuerung

Die aktive Kühlzuordnung im Werkseinstellungs-Gerätebaum des H5000M ändert PWM parallel zum Userspace-Controller. Damit die automatischen Kurven den Lüfter vollständig steuern können, wenden Sie den enthaltenen Patch vor dem Bau der Firmware an:

```sh
git apply package/luci-app-h5000m-fancontrol/openwrt-patches/h5000m-userspace-fan-control.patch
```

Der Patch entfernt nur die drei Lüfter-Cooling-Maps des H5000M; CPU-Throttling sowie die Hot- und Critical-Schwellen bleiben erhalten. Der Controller erzwingt außerdem eine höhere Lüfterausgabe, wenn die CPU ihren Hochtemperaturschwellwert erreicht.

Ohne den Patch läuft das Plugin weiter, aber der thermische Kernel-Governor kann die tatsächliche PWM anheben, sodass sich angeforderte und im UI angezeigte reale Lüfterausgabe unterscheiden können.

## Lüfterkarte der Werkseinstellungen (warum der Lüfter ≥ 50 % hält)

Ohne den Gerätebaum-Patch ist der Kernel weiterhin Mitbesitzer des Lüfters. Die werkseitige Kühlzuordnung des H5000M hält PWM ab 40 °C bei 128 (≈50 %), ab 85 °C bei 192 (≈75 %) und ab 115 °C bei 255, sodass jedes Profil — einschließlich Leise — durch die „Kernel-Sicherheitsuntergrenze“ begrenzt wird. Die LuCI-Seite zeigt die aus dem Gerätebaum gelesenen echten Schwellenwerte.

Empfohlen: Firmware mit `openwrt-patches/h5000m-userspace-fan-control.patch` bauen. Experimentelle Alternative: „Lüfterkarte der Firmware ignorieren“ in den Plugin-Einstellungen aktivieren, damit die Kurve unter die Firmware-Stufen läuft. Der Kernel schreibt seine eigene Stufe beim Überschreiten einer Schwelle neu, erwarten Sie daher einen kurzen Sprung bei 40/85/115 °C; der Hot/Critical-CPU-Schutz ist nicht betroffen.

## Überprüfung der Modem-Telemetrie

Die optionale Quelle `/tmp/5gmodem/tele.json` (luci-app-5gmodem-Telemetrie)
wird ohne zusätzliche Abhängigkeiten geparst. Es wird genau ein vollständiges
flaches JSON-Objekt akzeptiert; verwendet werden numerische Ganzzahlfelder der
obersten Ebene: `temp` von -40–150 °C und `therm` von 0–3. Zeichenketten,
Booleans, null, Bruch- oder außerhalb-des-Bereichs-Werte, abgeschnittene
Dokumente und nachfolgender Inhalt liefern keine Werte; Dateien älter als
90 s oder mit zukünftigem Datum werden ignoriert. Temperaturpriorität:
MT5700M-Cache → 5gmodem-Telemetrie → QModem-Cache.
Drosselstufen 1/2/3 setzen den PWM-Mindestwert auf 128/192/255, nur während
die App den Lüfter steuert; die höhere Kernel-Kühlgrenze hat weiterhin
Vorrang.

## Selbstupdate

Die Verwaltungsseite hat einen Tab „Update“, der das neueste **stabile**
GitHub-Release dieser App anbietet (`releases/latest`). Ein optionales
Kontrollkästchen „Beta-Releases anbieten“ listet `-beta.N`-Vorabversionen mit
einem Button „Beta installieren“ und einer Warnung, dass Beta-Builds instabil
sein können und für den täglichen Gebrauch nicht empfohlen werden. „Nach
Updates suchen“ vergleicht die installierte Version mit dem neuesten Release;
„Update installieren“ lädt das Anwendungspaket und — sofern veröffentlicht —
die russische Oberfläche (`luci-i18n-h5000m-fancontrol-ru`) für den
Paketmanager des Routers (`.apk` auf SNAPSHOT/apk, `.ipk` auf opkg) herunter
und installiert sie im Hintergrund mit Fortschrittsanzeige.

Der Updater prüft GitHub-Releases über die normale Internetverbindung des Routers (ohne Proxy). Nach einem erfolgreichen Update lädt die Seite neu und Sie melden sich erneut an, damit die aktualisierte Oberfläche und die RPC-Rechte sofort greifen. Es werden nur Release-Assets dieses Repositories heruntergeladen — es werden keine Gerätedaten hochgeladen.

## Konfiguration & Dienste

- UCI-Konfiguration: `/etc/config/h5000m_fancontrol`
- procd-Dienst: `/etc/init.d/h5000m-fancontrol`
- Controller: `/usr/sbin/h5000m-fancontrol`
- Updater-Skript: `/usr/share/h5000m-fancontrol/update.sh`
- LuCI-Seite: System → Lüftersteuerung

Häufige Befehle:

```sh
/usr/sbin/h5000m-fancontrol status
/usr/sbin/h5000m-fancontrol apply
/etc/init.d/h5000m-fancontrol restart
```

## Tests

- `tests/test-*.sh` — POSIX-Shell-Regressionstests für Controller, Updater und Helfer; alle ausführen mit `for t in tests/test-*.sh; do sh "$t"; done` (der CI-Job `static-checks` läuft über denselben Satz plus ShellCheck):
  - `test-lib.sh` — Unit-Tests für die `lib.sh`-Helfer (Kurvenberechnung, Temperaturparser, Cache/Metrik-Parser);
  - `test-config-load.sh` — Laden und Säubern der Konfiguration im Controller (mit Stub-`uci`);
  - `test-module-temperature.sh` — MT5700M-Modemtemperatur aus dem Datei-Cache;
  - `test-vendor-temperature.sh` — Hersteller-Radiotemperatur via `iwpriv` (nur Funktionen, berührt den Lüfter nie);
  - `test-thermal-policy-safety.sh` — Sicherheitsinvarianten: Der Controller darf die CPU-Thermalzone nicht nach `user_space` versetzen und muss die Kontrolle freigeben;
  - `test-uci-defaults.sh` — die `uci-defaults`-Migrationsskripte (91/92/93) auf einem isolierten Speicher;
  - `test-update.sh` — Unit-Tests für die `update.sh`-Helfer (Versionen, Assets, Sprachen, JSON-Escaping, apk-Fehleranalyse) plus CLI-Smoke.
- `tests/ui/states-test.mjs` — visueller Test der LuCI-Seite in Fehlerzuständen: keine Temperaturquelle, Modem abwesend, kein Wi-Fi-Funkmodul, Kernel hält die Richtlinie, Failsafe, veralteter Status, aktive Herunterregel-Verzögerung, manueller Modus. Er tauscht das Status-Skript des Routers (`/usr/sbin/h5000m-fancontrol-status`) vorübergehend gegen einen Stub mit vorbereitetem `key=value`-Payload, wartet den erwarteten Zustand ab, screenshotet die gerenderte Seite und stellt das Original wieder her (per MD5 verifiziert); der Daemon steuert den Lüfter währenddessen weiterhin real. Ausgabe: `preview/ui-states/report.html`. Aufruf:

  ```sh
  cd tests/ui && npm install
  H5FAN_PASS=<LuCI-Passwort> node states-test.mjs
  ```

  Details und Szenarioformat: `tests/ui/README.md`.

## Sicherheitshinweise

Die Lüftersteuerung ist eine gerätesicherheitsrelevante Funktion. Beobachten Sie die Temperaturen nach dem Ändern einer benutzerdefinierten Kurve oder des manuellen PWM genau. Der Controller verwaltet nur die Lüfter-PWM und versetzt niemals die gesamte CPU-Thermalzone in `user_space`; unabhängig davon, ob der exklusive Lüfter-Patch angewendet wurde, dürfen CPU-Throttling sowie die Hot- und Critical-Schutzeinträge im Gerätebaum nicht entfernt werden.

## Lizenz

[Apache License 2.0](LICENSE)

</details>
