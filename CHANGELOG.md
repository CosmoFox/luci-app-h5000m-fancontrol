# Changelog

🇬🇧 **English** | [🇷🇺 Русский](#ru) | [🇨🇳 简体中文](#zh) | [🇩🇪 Deutsch](#de)

*The English changelog is canonical; the other languages are translations kept in sync manually.*

## 2.2.0

- Redesigned dashboard: an interactive canvas chart plots the fan curve over
  the kernel floor map with a live current-temperature marker, the hysteresis
  band and a colour legend; it animates smoothly, follows the dark/light theme
  and stacks on narrow screens.
- The cards show CPU, Ethernet PHY, Wi-Fi and modem temperatures with
  "Priority"/"Offline" badges and the modem model.
- Quality: seven POSIX shell regression suites plus a failure-state visual
  test of the LuCI page; CI runs ShellCheck, version/changelog sync,
  translation coverage, embedded-catalog sync and the whole shell suite under
  busybox ash.
- Documentation: a single merged changelog in four languages and a CI/build
  pipeline diagram.
- The "Policy reason" chip is renamed to "Current status" (en/ru/zh/de).
- The package dependencies gained `jsonfilter`, `uclient-fetch` and
  `ca-bundle` (the updater needs them on minimal images); the unused
  `PKG_PO_VERSION` is removed.
- The fan curve chart continues flat from the last configured point to the
  right edge - mirroring the controller, which holds the last value.
- The changelogs are merged into a single file after the documentation
  pattern: Russian, German and Chinese live in collapsible blocks, and German
  is added.
- The page header now shows the installed app version next to the title.
- Fixed manual-mode saves: the slider value is always submitted with the form.
- Release automation: `scripts/release.sh` with `docs/RELEASING.md` cuts
  stable and beta tags with local validation; the workflow checks the
  tag/branch/version rules, caches the OpenWrt SDK, runs strict artifact
  checks and publishes SHA256SUMS, the build key and BUILD-INFO.txt.
- Release builds in GitHub Actions now cache the OpenWrt SDK archive (keyed
  on its sha256), so the multi-hundred-MB SDK is no longer downloaded on
  every run.
- Documentation (README and changelog) is maintained in English, Russian,
  German and Simplified Chinese.
- Sensors that report no temperature now show as unavailable on the LuCI
  page: the card is greyed out and the "Priority" badge becomes "Offline".
- Built-in in-app update, including installing beta versions (`-beta.N`), and
  a reinstall-current mechanism.
- After a successful update the browser force-reloads the new page scripts and
  the session ends once (a single re-login), so the updated interface and RPC
  permissions apply immediately.
- LuCI addition: while the controller holds the raised speed during the
  speed-down delay, the applied-output block shows a progress bar with the
  remaining seconds.
- luci-app-5gmodem telemetry (`/tmp/5gmodem/tele.json`, freshness-gated, no
  extra dependencies) supplies the modem temperature, the model name and the
  throttling level; levels 1/2/3 raise the fan output to at least 50/75/100%
  while the app controls the fan, the higher kernel floor keeps precedence,
  and the modem card names the level. When no modem source is present, the
  card offers a one-click install of the 5gmodem package.
- The status output reports the firmware fan map (`kernel_floor_levels`, e.g.
  `40=128,85=192,115=255`), and the LuCI page shows the exact thresholds
  instead of a generic "kernel safety floor" note.
- Added an experimental `override_floor` option (schema v4, off by default)
  letting automatic and manual output run below the stock firmware fan map;
  kernel trip enforcement and failsafe behaviour are preserved. It works
  without the stock-threshold patch, but is not stable.
- Documented the stock 40/85/115 °C thresholds and their patch-based fix.
- Retuned the silent fan curve: `20:0,35:0,40:20,50:20,60:40,70:50,85:100,95:100`
  for genuinely quiet and efficient operation.
- Added a schema v3 migration that replaces only the untouched factory silent
  curve.
- The language packs now ship inside the main application package.
- Added a Russian translation of the interface.
- Added a German translation of the interface.

## 2.1.3

- luci-app-5gmodem telemetry support: `/tmp/5gmodem/tele.json` (freshness
  check, parsed with jq) adds to the modem temperature sources, and the
  modem-reported throttling level (1/2/3) raises the fan output to at least
  128/192/255 while the app controls the fan; the higher kernel floor keeps
  precedence (#3, @fildunsky).
- Detection of MT7915/MT7916 radio temperature sensors (#5, @fildunsky).
- Russian translation of the interface (#4, @fildunsky).

## 2.1.2

- Built for OpenWrt 25.12.6: SDK and release build script updates.

## 2.1.1

- Bounded support for MTK vendor radio temperatures via iwpriv: sane values
  only (up to 125 °C); invalid answers leave the sensor unavailable.
- Minor CI and release workflow fixes.

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

<a id="ru"></a>

<details>
<summary><b>🇷🇺 Русский</b></summary>

# История изменений

## 2.2.0

- Переработанная панель: интерактивный график на canvas рисует кривую
  вентилятора поверх карты порогов ядра с живым маркером текущей температуры,
  полосой гистерезиса и цветовой легендой; плавно анимируется, подстраивается
  под тёмную/светлую тему и на узких экранах переходит в вертикальную
  раскладку.
- Карточки показывают температуры CPU, Ethernet PHY, Wi-Fi и
  модема с бейджами «Приоритет»/«Недоступно» и моделью модема.
- Качество: семь регрессионных наборов на POSIX shell плюс визуальный тест
  состояний отказа страницы LuCI; CI гоняет ShellCheck, сверку версий с
  чейнджлогом, покрытие переводов, синхронность встроенных каталогов и весь
  шелл-набор под busybox ash.
- Документация: единый объединённый чейнджлог на четырёх языках, схема CI/build-пайплайна.
- Чип «Причина политики» переименован в «Текущий статус» (en/ru/zh/de).
- В зависимости пакета добавлены jsonfilter, uclient-fetch и ca-bundle
  (обновлятору они нужны на минимальных образах); неиспользуемая
  PKG_PO_VERSION удалена.
- График кривой продолжается горизонтально от последней заданной точки до
  правого края — как поведение контроллера, держащего последнее значение.
- Чейнджлоги объединены в один файл по образцу документации: русский, немецкий и
  китайский — в сворачиваемых блоках, добавлен немецкий.
- В заголовке страницы рядом с названием теперь показывается установленная
  версия приложения.
- Исправлено сохранение ручного режима: значение ползунка теперь всегда
  передаётся при сохранении формы.
- Автоматизация релизов: `scripts/release.sh` с `docs/RELEASING.md` режет
  теги стабильных и бета-версий с локальной валидацией; workflow сверяет
  правила тега/ветки/версии, кэширует OpenWrt SDK, выполняет строгие проверки
  артефактов и публикует SHA256SUMS, ключ сборки и BUILD-INFO.txt.
- Сборки релизов в GitHub Actions теперь кэшируют архив OpenWrt SDK (ключ —
  его sha256), поэтому SDK на сотни мегабайт больше не скачивается при каждом
  запуске.
- Документация (README и журнал изменений) ведётся на английском, русском, немецком и
  упрощённом китайском.
- Датчики, которые не отдают температуру, теперь показываются на странице
  LuCI как недоступные: карточка затемняется, а бейдж «Приоритет» заменяется
  на «Недоступен».
- Встроенный механизм обновления приложения, включая установку бета-версий (`-beta.N`). Механизм переустановки текущей версии.
- После успешного обновления браузер принудительно перезагружает новые
  скрипты страницы, а сессия завершается один раз (один повторный вход),
  чтобы обновлённый интерфейс и новые RPC-права применились сразу.
- Новое в LuCI: пока контроллер удерживает повышенные обороты в задержке
  снижения скорости, в блоке фактической мощности показывается полоса
  прогресса с оставшимися секундами.
- Телеметрия luci-app-5gmodem (`/tmp/5gmodem/tele.json`, с контролем свежести,
  без лишних зависимостей) отдаёт температуру модема, имя модели и уровень
  троттлинга; уровни 1/2/3 поднимают выход вентилятора минимум до 50/75/100 %,
  пока приложение управляет вентилятором, более высокий порог ядра в
  приоритете, а карточка модема называет уровень. Если источника модема нет,
  карточка предлагает установить пакет 5gmodem в один клик.
- Вывод на карту вентилятора `kernel_floor_levels`, напр. `40=128,85=192,115=255`, а страница LuCI
  показывает точные пороги вместо общей заметки о «безопасном пороге ядра».
- Добавлена экспериментальная опция `override_floor` (схема v4, по умолчанию
  выключена), позволяющая автоматическому и ручному режимам работать ниже
  штатной карты вентилятора прошивки; принудительные пороги ядра и аварийная
  защита сохранены. Работает без применения патча штатных порогов, но не стабильно.
- Задокументированы штатные пороги 40/85/115 °C и их решение через патч.
- Перенастроена тихая кривая вентилятора: `20:0,35:0,40:20,50:20,60:40,70:50,85:100,95:100` для реально тихой и эффективной работы.
- Добавлена миграция схемы v3, заменяющая только нетронутую заводскую тихую кривую.
- Языковые пакеты теперь входят в пакет основного приложения.
- Добавлен русский перевод интерфейса.
- Добавлен немецкий перевод интерфейса.

## 2.1.3

- Поддержка телеметрии luci-app-5gmodem: `/tmp/5gmodem/tele.json` (проверка
  свежести, разбор через jq) дополняет источники температуры модема, а
  сообщаемый модемом уровень троттлинга (1/2/3) поднимает выход вентилятора
  минимум до 128/192/255, пока приложение управляет вентилятором; более
  высокий порог ядра сохраняет приоритет (#3, @fildunsky).
- Определение температурных датчиков радио MT7915/MT7916 (#5, @fildunsky).
- Русский перевод интерфейса (#4, @fildunsky).

## 2.1.2

- Сборка для OpenWrt 25.12.6: обновление SDK и скрипта сборки релизов.

## 2.1.1

- Ограниченная поддержка температур vendor-радио MTK через iwpriv: значения
  со смыслом (до 125 °C), при невалидных ответах датчик считается
  недоступным.
- Небольшие правки CI и Workflow релизов.
## 2.1.0

- Контроллер вентилятора больше не переводит всю thermal-зону CPU в `user_space`.
- Автоматически восстанавливается thermal policy, оставленная старыми
  версиями, с сохранением троттлинга CPU и защиты от перегрева.
- Чтение статуса и запись параметров используют отдельные RPC-полномочия.
- Конфигурация UCI объявлена conffile (сохраняется при обновлении).

## 2.0.2

- Чтение кэша температур с метками времени от менеджера MT5700M.
- Устаревшие температуры модулей старше 60 с игнорируются; совместимость со
  старым кэшем QModem сохранена.

## 2.0.1

- Единые правила версий GitHub Release и пакетов OpenWrt.
- Исправления совместимости сборок и поставки, накопленные после 2.0.0.

## 2.0.0

- Переработана страница управления охлаждением в LuCI для конечных пользователей.
- Добавлена сводка температур CPU, Ethernet PHY, Wi-Fi и 5G-модуля.
- Добавлены кривые «Тихая», «Сбалансированная», «Производительная» и произвольная.
- Добавлены температурный гистерезис, задержка остановки и стартовый буст.
- Добавлены аварийная защита при отказе датчика и нижний пользовательский
  порог безопасности при высоких температурах.
- Добавлен опциональный патч device tree H5000M, чтобы ядро и userspace не
  конкурировали за PWM.

---

*Канонической является английская версия журнала изменений; переводы синхронизируются вручную.*

</details>
---

<a id="zh"></a>

<details>
<summary><b>🇨🇳 简体中文</b></summary>

# 更新日志

## 2.2.0

- 重新设计的仪表盘：交互式 canvas 图表将风扇曲线绘制在内核下限映射
  之上，带实时当前温度标记、迟滞条带和颜色图例；动画平滑，自适应
  深色/浅色主题，在窄屏上自动切换为竖向布局。
- 状态卡片显示 CPU、以太网 PHY、Wi-Fi 和调制解调器的温度，带“优先”/“离线”
  徽标和调制解调器型号。
- 质量：七个 POSIX shell 回归套件外加页面故障状态的可视化测试；CI 运行
  ShellCheck、版本与变更日志一致性、翻译覆盖、内置目录同步检查，并在
  busybox ash 下运行整个 shell 套件。
- 文档：合并后的四语言变更日志和 CI/构建流水线示意图。
- “策略原因”卡片更名为“当前状态”（en/ru/zh/de）。
- 软件包依赖新增 `jsonfilter`、`uclient-fetch` 和 `ca-bundle`（更新程序在
  最小化镜像中需要它们）；未使用的 `PKG_PO_VERSION` 已删除。
- 风扇曲线图从最后一个配置点水平延伸至绘图右边缘——与控制器保持最后
  数值的行为一致。
- 变更日志按文档样式合并为单一文件：俄语、德语和中文置于可折叠区块中，
  并新增德语。
- 页面标题旁现在显示已安装的应用版本。
- 修复手动模式的保存：滑块值现在始终随表单提交。
- 发布自动化：`scripts/release.sh` 配合 `docs/RELEASING.md` 在本地校验后
  打稳定版与测试版标签；工作流校验标签/分支/版本规则，缓存 OpenWrt
  SDK，执行严格的工件检查，并发布 SHA256SUMS、构建密钥与 BUILD-INFO.txt。
- GitHub Actions 发布构建现在缓存 OpenWrt SDK 归档（以 sha256 为键），
  数百 MB 的 SDK 不再每次重新下载。
- 文档（README 与变更日志）以英文、俄文、德文和简体中文维护。
- 不上报温度的传感器现在在 LuCI 页面显示为不可用：卡片变灰，“优先”
  徽标变为“离线”。
- 内置应用内更新机制，包括安装测试版（`-beta.N`）；以及重新安装当前
  版本的机制。
- 更新成功后，浏览器强制重新加载新的页面脚本，并结束一次会话（需重新
  登录一次），以便更新后的界面与 RPC 权限立即生效。
- LuCI 新增：当控制器在降速延迟期间保持较高转速时，实际输出块显示
  剩余秒数的进度条。
- luci-app-5gmodem 遥测（`/tmp/5gmodem/tele.json`，带新鲜度校验，无额外
  依赖）提供调制解调器温度、型号名称和降频等级；等级 1/2/3 会在应用
  控制风扇时将输出至少提高到 50%/75%/100%，内核散热下限更高时仍然
  优先，调制解调器卡片显示当前等级。没有调制解调器数据源时，卡片提供
  一键安装 5gmodem 软件包。
- 状态输出现在报告固件风扇映射（`kernel_floor_levels`，例如
  `40=128,85=192,115=255`），LuCI 页面显示具体阈值，而不再只是笼统的
  “内核安全下限”提示。
- 新增实验性 `override_floor` 选项（模式 v4，默认关闭），允许自动与
  手动输出低于出厂固件风扇映射；内核 trip 强制机制和故障保护行为保持
  不变。无需修补出厂阈值即可工作，但不稳定。
- 文档补充了出厂 40/85/115 °C 阈值及基于补丁的解决方案。
- 重新调校静音风扇曲线：`20:0,35:0,40:20,50:20,60:40,70:50,85:100,95:100`，
  实现真正安静且高效的运行。
- 新增模式 v3 迁移，仅替换未被修改的出厂静音曲线。
- 语言包现在随主应用程序包一同提供。
- 新增界面俄语翻译。
- 新增界面德语翻译。

## 2.1.3

- 支持 luci-app-5gmodem 遥测：`/tmp/5gmodem/tele.json`（新鲜度校验，
  通过 jq 解析）补充调制解调器温度来源；调制解调器上报的降频等级
  （1/2/3）会在应用控制风扇时将输出至少提高到 128/192/255，内核散热
  下限更高时仍然优先（#3, @fildunsky）。
- 识别 MT7915/MT7916 射频温度传感器（#5, @fildunsky）。
- 新增界面俄语翻译（#4, @fildunsky）。

## 2.1.2

- 为 OpenWrt 25.12.6 构建：更新 SDK 与发布构建脚本。

## 2.1.1

- 通过 iwpriv 对 MTK 厂商射频温度提供有界支持：仅接受合理值（不超过
  125 °C）；无效响应视为传感器不可用。
- CI 与发布工作流的小幅修正。
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

- 重新设计面向最终用户的 LuCI 散热管理界面。
- 增加 CPU、以太网 PHY、Wi-Fi 和 5G 模块温度汇总。
- 增加静音、均衡、性能及自定义风扇曲线。
- 增加温度滞回、降速延迟和启动助推。
- 增加传感器故障保护及高温用户空间安全下限。
- 增加可选 H5000M 设备树补丁，避免内核与用户空间争用 PWM。


---

*更新日志以英文版本为准；其他语言为人工同步的译文。*

</details>
---

<a id="de"></a>

<details>
<summary><b>🇩🇪 Deutsch</b></summary>

# Änderungsprotokoll

## 2.2.0

- Neu gestaltetes Dashboard: Ein interaktives Canvas-Diagramm zeichnet die
  Lüfterkurve über der Kernel-Grenzenkarte mit einem Live-Marker für die
  aktuelle Temperatur, dem Hystereseband und einer Farblegende; es animiert
  weich, folgt dem dunklen/hellen Theme und stapelt sich auf schmalen
  Bildschirmen.
- Die Karten zeigen Temperaturen von CPU, Ethernet-PHY, Wi-Fi und Modem mit
  „Priorität"-/„Offline"-Badges und dem Modellnamen.
- Qualität: sieben POSIX-Shell-Regressionssuiten plus ein Visualisierungstest
  der LuCI-Seite in Fehlerzuständen; die CI läuft ShellCheck, Versions-/
  Änderungsprotokoll-Abgleich, Übersetzungsabdeckung, eingebettete
  Katalogsynchronisation und das gesamte Shell-Sortiment unter busybox ash.
- Dokumentation: ein zusammengeführtes Änderungsprotokoll in vier Sprachen und
  ein Diagramm der CI/Build-Pipeline.
- Der Chip „Richtlinien-Grund" wurde in „Aktueller Status" umbenannt (en/ru/zh/de).
- Die Paketabhängigkeiten ergänzen `jsonfilter`, `uclient-fetch` und
  `ca-bundle` (der Updater braucht sie auf Minimalimages); die ungenutzte
  `PKG_PO_VERSION` wurde entfernt.
- Das Lüfterkurvendiagramm läuft ab dem letzten konfigurierten Punkt flach bis
  zur rechten Kante - entsprechend dem Verhalten des Controllers, der den
  letzten Wert hält.
- Die Änderungsprotokolle sind nach dem Dokumentationsmuster zu einer Datei
  zusammengeführt: Russisch, Deutsch und Chinesisch liegen in aufklappbaren
  Blöcken, und Deutsch wurde hinzugefügt.
- Der Seitenkopf zeigt jetzt die installierte App-Version neben dem Titel.
- Speichern im manuellen Modus korrigiert: Der Schiebereglerwert wird beim
  Absenden des Formulars immer übertragen.
- Release-Automatisierung: `scripts/release.sh` mit `docs/RELEASING.md`
  schneidet Stabil- und Beta-Tags mit lokaler Validierung; der Workflow prüft
  Tag/Branch/Versionsregeln, cached das OpenWrt-SDK, führt strikte
  Artefaktprüfungen durch und veröffentlicht SHA256SUMS, den Build-Schlüssel
  und BUILD-INFO.txt.
- Release-Builds in GitHub Actions cachen das OpenWrt-SDK-Archiv (Schlüssel:
  sein sha256), sodass das mehrere hundert MB große SDK nicht mehr bei jedem
  Lauf heruntergeladen wird.
- Dokumentation (README und Änderungsprotokoll) wird auf Englisch, Russisch,
  Deutsch und Vereinfachtem Chinesisch gepflegt.
- Sensoren ohne Temperatur werden auf der LuCI-Seite jetzt als nicht verfügbar
  gezeigt: Die Karte ist ausgegraut und das „Priorität"-Badge wird zu „Offline".
- Eingebautes In-App-Update, einschließlich der Installation von Beta-Versionen
  (`-beta.N`), und ein Mechanismus zur Neuinstallation der aktuellen Version.
- Nach einem erfolgreichen Update lädt der Browser die neuen Skripte erzwungen
  neu und die Sitzung wird einmal beendet (eine erneute Anmeldung), damit die
  aktualisierte Oberfläche und die RPC-Rechte sofort greifen.
- LuCI-Neuerung: Während der Controller die erhöhte Drehzahl in der
  Herunterregel-Verzögerung hält, zeigt der Block der tatsächlichen Ausgabe
  einen Fortschrittsbalken mit den verbleibenden Sekunden.
- luci-app-5gmodem-Telemetrie (`/tmp/5gmodem/tele.json`,
  Frischekeitsbegrenzung, ohne Zusatzabhängigkeiten) liefert Modemtemperatur,
  Modellnamen und Drosselstufe; Stufen 1/2/3 heben die Lüfterausgabe auf
  mindestens 50/75/100 % an, solange die App den Lüfter steuert, die höhere
  Kernel-Grenze hat weiterhin Vorrang, und die Modem-Karte nennt die Stufe. Ist
  keine Modemquelle vorhanden, bietet die Karte die Ein-Klick-Installation des
  5gmodem-Pakets an.
- Die Statusausgabe meldet die Firmware-Lüfterkarte (`kernel_floor_levels`,
  z. B. `40=128,85=192,115=255`), und die LuCI-Seite zeigt die exakten
  Schwellen statt nur einer generischen Notiz zur „Kernel-Sicherheitsgrenze".
- Neue experimentelle Option `override_floor` (Schema v4, standardmäßig aus),
  die automatischen und manuellen Betrieb unter die werkseitige
  Firmware-Lüfterkarte erlaubt; Kernel-Trip-Durchsetzung und Failsafe-Verhalten
  bleiben erhalten. Funktioniert ohne Patch der Werksschwellen, ist aber nicht
  stabil.
- Die werkseitigen Schwellen 40/85/115 °C und ihre Lösung per Patch wurden
  dokumentiert.
- Leise Lüfterkurve neu abgestimmt: `20:0,35:0,40:20,50:20,60:40,70:50,85:100,95:100`
  für wirklich leisen und effizienten Betrieb.
- Schema-Migration v3 hinzugefügt, die nur die unveränderte werkseitige leise
  Kurve ersetzt.
- Die Sprachpakete liegen jetzt im Hauptanwendungspaket.
- Russische Übersetzung der Oberfläche hinzugefügt.
- Deutsche Übersetzung der Oberfläche hinzugefügt.

## 2.1.3

- Unterstützung der luci-app-5gmodem-Telemetrie: `/tmp/5gmodem/tele.json`
  (Frischeprüfung, Parsing via jq) ergänzt die Quellen der Modemtemperatur, und
  die vom Modem gemeldete Drosselstufe (1/2/3) hebt die Lüfterausgabe auf
  mindestens 128/192/255 an, solange die App den Lüfter steuert; die höhere
  Kernel-Grenze hat weiterhin Vorrang (#3, @fildunsky).
- Erkennung der Temperatursensoren der Radios MT7915/MT7916 (#5, @fildunsky).
- Russische Übersetzung der Oberfläche (#4, @fildunsky).

## 2.1.2

- Build für OpenWrt 25.12.6: SDK- und Release-Build-Skript aktualisiert.

## 2.1.1

- Begrenzte Unterstützung von MTK-Vendor-Radiotemperaturen via iwpriv: nur
  plausible Werte (bis 125 °C); ungültige Antworten lassen den Sensor nicht
  verfügbar erscheinen.
- Kleinere Korrekturen an CI und Release-Workflow.
## 2.1.0

- Der Lüfter-Controller versetzt die gesamte CPU-Thermalzone nicht mehr in `user_space`.
- Stellt die von älteren Versionen hinterlassene Thermorichtlinie automatisch
  wieder her, mit Erhalt von CPU-Throttling und Überhitzungsschutz.
- Statuslesezugriff und Steuerschreibzugriff nutzen getrennte RPC-Rechte.
- Die UCI-Konfiguration wurde als conffile deklariert (bleibt bei Upgrades erhalten).

## 2.0.2

- Liest den mit Zeitstempel versehenen Temperatur-Cache des MT5700M-Managers.
- Ignoriert veraltete Modultemperaturen älter als 60 s und bleibt kompatibel
  zum Legacy-QModem-Cache.

## 2.0.1

- Vereinheitlichte Versionsregeln für GitHub-Releases und OpenWrt-Pakete.
- Nach 2.0.0 angesammelte Build-Kompatibilitäts- und Auslieferungsrevisionen.

## 2.0.0

- Die Endanwender-LuCI-Seite zur Thermoverwaltung wurde neu gestaltet.
- Temperaturaggregation für CPU, Ethernet-PHY, Wi-Fi und das 5G-Modul hinzugefügt.
- Leise, ausgewogene, Leistungs- und benutzerdefinierte Lüfterkurven hinzugefügt.
- Temperaturhysterese, verzögertes Herunterregeln und Start-Boost hinzugefügt.
- Sensor-Ausfallschutz und eine Userspace-Sicherheitsuntergrenze bei hohen
  Temperaturen hinzugefügt.
- Optionaler H5000M-Gerätebaum-Patch, damit Kernel und Userspace nicht um
  PWM konkurrieren.

---

---

*Das englische Änderungsprotokoll ist maßgeblich; die übrigen Sprachen werden manuell synchron gehalten.*

</details>
