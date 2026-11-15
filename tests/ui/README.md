# Failure-state UI visual tests

`states-test.mjs` shows how the app's LuCI page looks in degraded states:
no temperature source, modem absent, no Wi-Fi radio, kernel-owned thermal
policy, failsafe, stale status, active speed-down delay and manual mode.

## How it works

The page reads its data from `/usr/sbin/h5000m-fancontrol-status`
(`key=value` lines, polled every ~3 s). For each scenario the script:

1. temporarily replaces that binary on the router with a stub printing the
   crafted payload (the original is backed up in `/tmp` and restored with an
   md5 check at the end - also on error);
2. reloads the app page and waits for a deterministic sign of the state
   (badge class `fail`/`warn`, element visibility, element text);
3. screenshots the full page and close-ups: status badge, temperature grid,
   curve chart, safety note, modem banner (when visible);
4. moves on to the next scenario.

The `h5000m-fancontrol` daemon keeps running throughout - only what the page
shows is faked, the fan stays under real control.

## Requirements

- Node.js (ES modules, top-level await);
- a system Edge or Chrome (headless). Without them -
  `npx playwright install chromium`;
- root SSH access to the router; the password is passed only via an
  environment variable, the temporary askpass file lives for the run only.

## Running

```bash
cd tests/ui
npm install
H5FAN_PASS=<LuCI password> node states-test.mjs
```

Environment variables:

- `H5FAN_BASE` - router URL, required (e.g. `http://192.168.1.1`);
- `H5FAN_USER` - LuCI user, default `root`;
- `H5FAN_PASS` - LuCI password (required).

## Output

`preview/ui-states/` (gitignored): 4-6 PNGs per scenario plus the restored
page (`99-restored-full.png`) and `report.html` - all states side by side
with the description, expectation and a collapsible payload. The exit code is
non-zero if any scenario missed its expected state or the page had JS errors.

## Scenarios

| id | State | What is checked |
|----|-------|-----------------|
| `10-normal` | Normal | Baseline shot for comparison |
| `20-no-temp-source` | No temperature source | Cards "Unavailable", "No valid sensor", red failsafe badge, 100% request |
| `30-modem-absent` | Modem absent | Modem card "Unavailable" + "5gmodem package required" banner |
| `40-no-wifi` | No Wi-Fi radio | Wi-Fi card "Unavailable", Offline badge |
| `50-kernel-owner` | Kernel owns the policy | Firmware fan map note, floor line on the chart |
| `60-failsafe` | Failsafe with live sensors | Red badge, curve-failsafe reason |
| `70-status-delayed` | Stale status | Amber "Status delayed" badge |
| `80-down-delay` | Speed-down delay active | "42 s" countdown and progress bar in the Applied output chip |
| `90-manual` | Manual mode | Manual profile, flat request line on the chart |

## Adding a scenario

Add an object to the `scenarios` array:

```js
{
	id: '95-my-case',
	name: '…',
	desc: '…',
	// payload is built from the router's live output: baseText + edits;
	// an undefined value removes the key
	payload: patch(baseText, { reason: 'kernel', result: 'ok' }),
	// expectation (any combination):
	expect: {
		healthClass: 'fail',                    // '' - exactly the base class
		visible: '#h5fan-modem-setup',          // element must become visible
		textIncludes: ['#h5fan-adsec', '42']    // element text contains a substring
	}
}
```

The payload keys follow `print_status` in `root/usr/sbin/h5000m-fancontrol`
(`cpu_temp`, `control_sensor`, `kernel_floor_levels`, `thermal_owner`,
`requested_pwm`, `down_remaining`, `state_age`, …).

## Safety

- The status binary is swapped for seconds; the original is backed up
  (`/tmp/h5000m-fancontrol-status.real`) and restored in a `finally` block
  with an md5 check.
- The fan control daemon is neither stopped nor modified.
- The script never clicks update/install buttons and never changes UCI
  settings.

<a id="ru"></a>

<details>
<summary><b>🇷🇺 Русский</b></summary>

# Визуальные тесты состояний отказа UI

`states-test.mjs` показывает, как страница приложения в LuCI выглядит в
деградированных состояниях: при пропаже источников температуры, отсутствии
модема или радиомодуля, переходе политики к ядру, failsafe, устаревшем
статусе, активной задержке снижения оборотов и в ручном режиме.

## Принцип

Страница получает данные, опрашивая `/usr/sbin/h5000m-fancontrol-status`
(строки `key=value`, период ~3 с). Для каждого сценария скрипт:

1. временно подменяет этот бинарник на роутере заглушкой, печатающей
   подготовленный payload (оригинал сохраняется в `/tmp`, в конце возвращается
   и сверяется по md5 — в том числе при ошибке);
2. перезагружает страницу приложения и дожидается детерминированного признака
   состояния (класс бейджа `fail`/`warn`, видимость элемента, текст);
3. снимает полную страницу и крупные планы: бейдж состояния, сетку температур,
   график кривой, заметку безопасности, плашку модема (если видна);
4. идёт к следующему сценарию.

Демон `h5000m-fancontrol` при этом продолжает работать — подделывается только
то, что видит страница, вентилятор остаётся под реальным контролем.

## Требования

- Node.js (ES-модули, top-level await);
- системный Edge или Chrome (headless). Если их нет — `npx playwright install chromium`;
- SSH-доступ (root) к роутеру; пароль передаётся только через переменную
  окружения, временный askpass-файл создаётся на время прогона и удаляется.

## Запуск

```bash
cd tests/ui
npm install
H5FAN_PASS=<пароль LuCI> node states-test.mjs
```

Переменные окружения:

- `H5FAN_BASE` — URL роутера, обязателен (например, `http://192.168.1.1`);
- `H5FAN_USER` — пользователь LuCI, по умолчанию `root`;
- `H5FAN_PASS` — пароль LuCI (обязателен).

## Результат

`preview/ui-states/` (в `.gitignore`): по 4–6 PNG на сценарий + полная страница
после восстановления (`99-restored-full.png`) + `report.html` — все состояния
рядом с описанием, ожиданием и раскрывающимся payload. Код выхода ненулевой,
если какой-то сценарий не достиг ожидаемого состояния или на странице были
JS-ошибки.

## Сценарии

| id | Состояние | Что проверяется |
|----|-----------|-----------------|
| `10-normal` | Норма | Базовый снимок для сравнения |
| `20-no-temp-source` | Нет источника температуры | Карточки «Недоступно», «Нет достоверного датчика», красный бейдж failsafe, запрос 100 % |
| `30-modem-absent` | Модем отсутствует | Карточка модема «Недоступно» + плашка «требуется пакет 5gmodem» |
| `40-no-wifi` | Нет модуля Wi-Fi | Карточка Wi-Fi «Недоступно», бейдж Offline |
| `50-kernel-owner` | Политику держит ядро | Заметка с firmware fan map, линия floor на графике |
| `60-failsafe` | Failsafe при живых датчиках | Красный бейдж, причина curve-failsafe |
| `70-status-delayed` | Статус устарел | Янтарный бейдж «Status delayed» |
| `80-down-delay` | Задержка снижения оборотов | Отсчёт «42 s» и прогресс-бар в чипе Applied output |
| `90-manual` | Ручной режим | Профиль Manual, плоская линия запроса на графике |

## Как добавить сценарий

Новый объект в массиве `scenarios`:

```js
{
	id: '95-my-case',
	name: '…',
	desc: '…',
	// payload строится от живого вывода роутера: baseText + правки;
	// значение undefined удаляет ключ
	payload: patch(baseText, { reason: 'kernel', result: 'ok' }),
	// ожидание (любое сочетание):
	expect: {
		healthClass: 'fail',                    // '' — ровно базовый класс
		visible: '#h5fan-modem-setup',          // элемент должен показаться
		textIncludes: ['#h5fan-adsec', '42']    // текст элемента содержит подстроку
	}
}
```

Список ключей payload — по `print_status` в `root/usr/sbin/h5000m-fancontrol`
(`cpu_temp`, `control_sensor`, `kernel_floor_levels`, `thermal_owner`,
`requested_pwm`, `down_remaining`, `state_age`, …).

## Безопасность

- Статус-бинарник подменяется на seconds-scale, оригинал бэкапится
  (`/tmp/h5000m-fancontrol-status.real`) и восстанавливается в `finally` с
  проверкой md5.
- Демон управления вентилятором не останавливается и не изменяется.
- Скрипт не нажимает кнопки установки обновлений и не меняет настройки UCI.

</details>

<a id="zh"></a>

<details>
<summary><b>🇨🇳 简体中文</b></summary>

# 故障状态 UI 可视化测试

`states-test.mjs` 展示应用的 LuCI 页面在降级状态下的外观：无温度源、
无调制解调器、无 Wi-Fi 射频、散热策略由内核持有、failsafe、状态过期、
降速延迟生效以及手动模式。

## 工作原理

页面通过轮询 `/usr/sbin/h5000m-fancontrol-status`（`key=value` 行，约每
3 秒一次）获取数据。每个场景脚本会：

1. 临时把路由器上的该二进制文件替换为打印指定 payload 的桩脚本（原文件
   备份在 `/tmp`，结束后校验 md5 并恢复——出错时同样恢复）；
2. 重新加载应用页面，等待状态的确定性信号（徽标类 `fail`/`warn`、元素
   可见性、元素文本）；
3. 截取整页及特写：状态徽标、温度网格、曲线图、安全说明、调制解调器
   提示条（可见时）；
4. 进入下一个场景。

整个过程中 `h5000m-fancontrol` 守护进程持续运行——只有页面显示内容被
模拟，风扇始终由真实控制器管理。

## 环境要求

- Node.js（ES 模块，top-level await）；
- 系统自带的 Edge 或 Chrome（headless）。如果没有——
  `npx playwright install chromium`；
- 路由器的 root SSH 访问；密码仅通过环境变量传入，临时 askpass 文件
  仅在运行期间存在。

## 运行

```bash
cd tests/ui
npm install
H5FAN_PASS=<LuCI 密码> node states-test.mjs
```

环境变量：

- `H5FAN_BASE` —— 路由器 URL，必填（例如 `http://192.168.1.1`）；
- `H5FAN_USER` —— LuCI 用户，默认 `root`；
- `H5FAN_PASS` —— LuCI 密码（必填）。

## 输出

`preview/ui-states/`（已加入 .gitignore）：每个场景 4–6 张 PNG，外加恢复
后的整页截图（`99-restored-full.png`）和 `report.html`——所有状态与描述、
期望值及可展开的 payload 并列展示。若有场景未达到预期状态或页面出现
JS 错误，退出码非零。

## 测试场景

| id | 状态 | 检查内容 |
|----|------|----------|
| `10-normal` | 正常 | 用于对比的基准截图 |
| `20-no-temp-source` | 无温度源 | 卡片显示"不可用"、"无有效传感器"，红色 failsafe 徽标，请求 100% |
| `30-modem-absent` | 无调制解调器 | 调制解调器卡片"不可用" + "需要 5gmodem 包"提示条 |
| `40-no-wifi` | 无 Wi-Fi 射频 | Wi-Fi 卡片"不可用"，Offline 徽标 |
| `50-kernel-owner` | 内核持有策略 | 固件风扇映射说明，图表上的 floor 线 |
| `60-failsafe` | 传感器正常时进入 failsafe | 红色徽标，curve-failsafe 原因 |
| `70-status-delayed` | 状态过期 | 琥珀色 "Status delayed" 徽标 |
| `80-down-delay` | 降速延迟生效 | Applied output 芯片中的 "42 s" 倒计时和进度条 |
| `90-manual` | 手动模式 | Manual 配置文件，图表上平坦的请求线 |

## 添加场景

在 `scenarios` 数组中添加对象：

```js
{
	id: '95-my-case',
	name: '…',
	desc: '…',
	// payload 基于路由器实时输出构建：baseText + 修改；
	// undefined 值删除该键
	payload: patch(baseText, { reason: 'kernel', result: 'ok' }),
	// 期望值（任意组合）：
	expect: {
		healthClass: 'fail',                    // '' —— 恰好为基础类名
		visible: '#h5fan-modem-setup',          // 元素必须可见
		textIncludes: ['#h5fan-adsec', '42']    // 元素文本包含子串
	}
}
```

payload 的键名见 `root/usr/sbin/h5000m-fancontrol` 中的 `print_status`
（`cpu_temp`、`control_sensor`、`kernel_floor_levels`、`thermal_owner`、
`requested_pwm`、`down_remaining`、`state_age` 等）。

## 安全性

- 状态二进制仅被替换数秒；原文件备份于
  `/tmp/h5000m-fancontrol-status.real`，并在 `finally` 中校验 md5 后恢复。
- 风扇控制守护进程不会被停止或修改。
- 脚本不会点击更新/安装按钮，也不会更改 UCI 设置。

</details>

<a id="de"></a>

<details>
<summary><b>🇩🇪 Deutsch</b></summary>

# Visualisierungstests für Fehlerzustände der UI

`states-test.mjs` zeigt, wie die App-Seite in LuCI in degenerierten Zuständen
aussieht: Temperaturquelle fällt aus, Modem fehlt, kein Wi-Fi-Funkmodul,
Richtlinie liegt beim Kernel, Failsafe, veralteter Status, aktive
Herunterregel-Verzögerung und manueller Modus.

## Funktionsweise

Die Seite bezieht ihre Daten aus `/usr/sbin/h5000m-fancontrol-status`
(`key=value`-Zeilen, Abfrage ca. alle 3 s). Für jedes Szenario:

1. ersetzt das Skript vorübergehend auf dem Router durch einen Stub, der den
   vorbereiteten Payload ausgibt (das Original liegt in `/tmp`, wird am Ende —
   auch bei Fehlern — zurückgespielt und per MD5 geprüft);
2. lädt die App-Seite neu und wartet auf ein deterministisches Zeichen des
   Zustands (Badge-Klasse `fail`/`warn`, Element-Sichtbarkeit, Text);
3. fotografiert die volle Seite und Ausschnitte: Status-Badge,
   Temperaturraster, Kurvendiagramm, Sicherheitshinweis, Modem-Banner (falls
   sichtbar);
4. geht zum nächsten Szenario über.

Der Daemon `h5000m-fancontrol` läuft weiter — nur die Anzeige wird simuliert,
der Lüfter bleibt unter echter Kontrolle.

## Voraussetzungen

- Node.js (ES-Module, Top-Level-Await);
- System-Edge oder Chrome (headless). Andernfalls `npx playwright install chromium`;
- root-SSH-Zugang zum Router; das Passwort wird nur über eine Umgebungsvariable
  übergeben, die temporäre Askpass-Datei existiert nur während des Laufs.

## Aufruf

```bash
cd tests/ui
npm install
H5FAN_PASS=<LuCI-Passwort> node states-test.mjs
```

Umgebungsvariablen:

- `H5FAN_BASE` — Router-URL, erforderlich (z. B. `http://192.168.1.1`);
- `H5FAN_USER` — LuCI-Benutzer, Vorgabe `root`;
- `H5FAN_PASS` — LuCI-Passwort (Pflicht).

## Ergebnis

`preview/ui-states/` (in `.gitignore`): 4–6 PNGs pro Szenario, plus die
wiederhergestellte Seite (`99-restored-full.png`) und `report.html` — alle
Zustände nebeneinander mit Beschreibung, Erwartung und aufklappbarem Payload.
Der Exitcode ist bei verfehlter Erwartung oder JS-Fehlern auf der Seite
ungleich null.

## Szenarien

| id | Zustand | Was geprüft wird |
|----|---------|------------------|
| `10-normal` | Normal | Basis-Screenshot zum Vergleich |
| `20-no-temp-source` | Keine Temperaturquelle | Karten „Nicht verfügbar“, „Kein gültiger Sensor“, rotes Failsafe-Badge, Anforderung 100 % |
| `30-modem-absent` | Modem fehlt | Modem-Karte „Nicht verfügbar“ + Banner „5gmodem-Paket erforderlich“ |
| `40-no-wifi` | Kein Wi-Fi-Funkmodul | Wi-Fi-Karte „Nicht verfügbar“, Offline-Badge |
| `50-kernel-owner` | Kernel hält die Richtlinie | Hinweis mit Firmware-Lüfterkarte, Floor-Linie im Diagramm |
| `60-failsafe` | Failsafe bei lebendigen Sensoren | Rotes Badge, Grund curve-failsafe |
| `70-status-delayed` | Status veraltet | Bernsteinfarbenes „Status delayed“-Badge |
| `80-down-delay` | Herunterregel-Verzögerung aktiv | Countdown „42 s“ und Fortschrittsbalken im Applied-Output-Chip |
| `90-manual` | Manueller Modus | Profil Manual, flache Anforderungslinie im Diagramm |

## Szenario hinzufügen

Neues Objekt im `scenarios`-Array:

```js
{
	id: '95-my-case',
	name: '…',
	desc: '…',
	// Payload wird aus der Live-Ausgabe des Routers gebaut: baseText + Änderungen;
	// undefined entfernt den Schlüssel
	payload: patch(baseText, { reason: 'kernel', result: 'ok' }),
	// Erwartung (beliebig kombinierbar):
	expect: {
		healthClass: 'fail',                    // '' — exakt die Basisklasse
		visible: '#h5fan-modem-setup',          // Element muss sichtbar werden
		textIncludes: ['#h5fan-adsec', '42']    // Elementtext enthält Substring
	}
}
```

Die Payload-Schlüssel folgen `print_status` in `root/usr/sbin/h5000m-fancontrol`
(`cpu_temp`, `control_sensor`, `kernel_floor_levels`, `thermal_owner`,
`requested_pwm`, `down_remaining`, `state_age`, …).

## Sicherheit

- Das Status-Binary wird nur für Sekunden getauscht; das Original wird
  gesichert (`/tmp/h5000m-fancontrol-status.real`) und in `finally` per MD5
  geprüft wiederhergestellt.
- Der Lüftersteuerungs-Daemon wird weder gestoppt noch verändert.
- Das Skript klickt keine Update-/Installations-Buttons und ändert keine
  UCI-Einstellungen.

</details>
