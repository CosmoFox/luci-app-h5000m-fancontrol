#!/usr/bin/env node
/*
 * Failure-state visual tests for the H5000M fan control LuCI page.
 *
 * The page reads its data from /usr/sbin/h5000m-fancontrol-status (polled
 * every few seconds). For every scenario this script temporarily replaces
 * that binary with a stub printing a crafted key=value payload - the page
 * then renders the degraded state for real: no temperature source, modem
 * gone, no Wi-Fi radio, kernel-owned thermal policy, failsafe, stale
 * status, active speed-down delay, manual mode. The original binary is
 * restored afterwards (also on error), and the report lets you eyeball
 * every state side by side.
 *
 * The real daemon keeps running untouched - only what the UI shows is
 * faked, so the hardware stays under normal control.
 *
 * Usage:
 *   H5FAN_PASS=<luci password> node states-test.mjs
 *
 * Environment: H5FAN_BASE (http://192.168.1.1), H5FAN_USER (root),
 * H5FAN_PASS (required), H5FAN_SSH_PORT (22).
 *
 * Output: ../../preview/ui-states/ (screenshots + report.html).
 */
import { chromium } from 'playwright-core';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(here, '../../preview/ui-states');
const BASE = (process.env.H5FAN_BASE || 'http://192.168.1.1').replace(/\/+$/, '');
const USER = process.env.H5FAN_USER || 'root';
const PASS = process.env.H5FAN_PASS;
const HOST = BASE.replace(/^https?:\/\//, '').replace(/\/.*$/, '');
const APP = BASE + '/cgi-bin/luci/admin/system/h5000m_fancontrol';
const STATUS_BIN = '/usr/sbin/h5000m-fancontrol-status';
const BACKUP = '/tmp/h5000m-fancontrol-status.real';

if (!PASS) {
	console.error('error: H5FAN_PASS is required (the LuCI password)');
	process.exit(2);
}

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

/* ---------------- SSH helpers (password via a temporary askpass) ------- */
const askpass = join(mkdtempSync(join(tmpdir(), 'h5fan-')), 'ask.sh');
writeFileSync(askpass, '#!/bin/sh\nprintf \'%s\' "$H5FAN_PASS"\n');
chmodSync(askpass, 0o600);
const sshEnv = { ...process.env, SSH_ASKPASS: askpass, SSH_ASKPASS_REQUIRE: 'force' };

function ssh(cmd) {
	const r = spawnSync('ssh', ['-o', 'StrictHostKeyChecking=accept-new', USER + '@' + HOST, cmd],
		{ env: sshEnv, encoding: 'utf8', timeout: 30000 });
	if (r.status !== 0)
		throw new Error('ssh failed: ' + cmd + '\n' + (r.stderr || '').trim().slice(0, 300));
	return r.stdout;
}

function scp(local, remote) {
	const r = spawnSync('scp', ['-O', local, USER + '@' + HOST + ':' + remote],
		{ env: sshEnv, encoding: 'utf8', timeout: 30000 });
	if (r.status !== 0)
		throw new Error('scp failed: ' + remote + '\n' + (r.stderr || '').trim().slice(0, 300));
}

/* ---------------- scenario payloads ------------------------------------ */
function toMap(text) {
	const m = new Map();
	for (const line of text.trim().split('\n')) {
		const i = line.indexOf('=');
		m.set(line.slice(0, i), line.slice(i + 1));
	}
	return m;
}

function fromMap(map) {
	return Array.from(map, ([k, v]) => k + '=' + v).join('\n') + '\n';
}

function patch(baseText, changes) {
	const m = toMap(baseText);
	for (const [k, v] of Object.entries(changes)) {
		if (v === undefined) m.delete(k);
		else m.set(k, v);
	}
	return fromMap(m);
}

const baseText = ssh(STATUS_BIN);
const baseBackupMd5 = ssh('md5sum ' + STATUS_BIN).split(/\s/)[0];

const scenarios = [
	{
		id: '10-normal',
		name: 'Нормальная работа',
		desc: 'Базовое состояние для сравнения: все датчики на месте, политика userspace.',
		payload: baseText,
		expect: { healthClass: '' }
	},
	{
		id: '20-no-temp-source',
		name: 'Нет источника температуры',
		desc: 'Все датчики пропали (cpu/phy/wifi пустые), контрольная температура отсутствует — карточки «Недоступно», причина sensor-failsafe, бейдж failsafe (красный), запрос 255.',
		payload: patch(baseText, {
			cpu_temp: '', cpu_label: '',
			phy_temp: '', phy_label: '',
			wifi1_temp: '', wifi1_label: '', wifi2_temp: '', wifi2_label: '',
			control_temp: '', control_sensor: '',
			result: 'failsafe', reason: 'sensor-failsafe',
			requested_pwm: '255', target_pwm: '255', applied_pwm: '255'
		}),
		expect: { healthClass: 'fail' }
	},
	{
		id: '30-modem-absent',
		name: 'Модем отсутствует',
		desc: 'module_temp/module_name пустые — карточка модема «Недоступно», появляется плашка «для мониторинга нужен пакет 5gmodem» с кнопкой установки.',
		payload: patch(baseText, { module_temp: '', module_name: '' }),
		expect: { visible: '#h5fan-modem-setup' }
	},
	{
		id: '40-no-wifi',
		name: 'Нет модуля радиосвязи',
		desc: 'wifi1/wifi2 пустые — карточка Wi-Fi «Недоступно», бейдж Offline, подписи датчиков пустые.',
		payload: patch(baseText, { wifi1_temp: '', wifi1_label: '', wifi2_temp: '', wifi2_label: '' }),
		expect: {}
	},
	{
		id: '50-kernel-owner',
		name: 'Политику держит ядро',
		desc: 'thermal_owner=kernel (приложение выключено или режим kernel) — заметка о firmware fan map с уровнями, на графике янтарная пунктирная линия floor.',
		payload: patch(baseText, {
			enabled: '0', thermal_owner: 'kernel', reason: 'kernel',
			kernel_floor_levels: '83=192,113=255', thermal_floor: '192',
			requested_pwm: '192', target_pwm: '192', applied_pwm: '192'
		}),
		expect: { textIncludes: ['#h5fan-safety-note', '83'] }
	},
	{
		id: '60-failsafe',
		name: 'Failsafe-охлаждение при живых датчиках',
		desc: 'result=failsafe (например, ошибка чтения кривой) — красный бейдж, причина curve-failsafe, вентилятор на максимуме.',
		payload: patch(baseText, {
			result: 'failsafe', reason: 'curve-failsafe',
			requested_pwm: '255', target_pwm: '255', applied_pwm: '255'
		}),
		expect: { healthClass: 'fail' }
	},
	{
		id: '70-status-delayed',
		name: 'Статус устарел',
		desc: 'state_age намного больше интервала — янтарный бейдж «Status delayed» (rpcd/статус-скрипт не отвечает).',
		payload: patch(baseText, { state_age: '300' }),
		expect: { healthClass: 'warn' }
	},
	{
		id: '80-down-delay',
		name: 'Активна задержка снижения оборотов',
		desc: 'down_remaining>0 — в чипе «Applied output» идёт обратный отсчёт с прогресс-баром.',
		payload: patch(baseText, { down_delay: '90', down_remaining: '42', reason: 'auto-down-delay' }),
		expect: { textIncludes: ['#h5fan-adsec', '42'] }
	},
	{
		id: '90-manual',
		name: 'Ручной режим',
		desc: 'mode=manual — профиль «Manual», плоская линия запроса на графике, причина «Manual request».',
		payload: patch(baseText, { mode: 'manual', manual_pwm: '200', reason: 'manual', requested_pwm: '200', target_pwm: '200', applied_pwm: '200' }),
		expect: {}
	}
];

/* ---------------- browser ---------------------------------------------- */
async function launchBrowser() {
	for (const channel of ['msedge', 'chrome', undefined]) {
		try {
			return await chromium.launch({ channel, headless: true });
		} catch { /* try the next one */ }
	}
	throw new Error('no usable browser found (install Edge/Chrome or run "npx playwright install chromium")');
}
const browser = await launchBrowser();
const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1.5, ignoreHTTPSErrors: true });
const page = await context.newPage();
const problems = [];
page.on('pageerror', err => problems.push('pageerror: ' + err.message));

async function shot(name) {
	const file = join(OUT, name + '.png');
	await page.screenshot({ path: file });
	return name + '.png';
}

async function login() {
	await page.goto(BASE + '/cgi-bin/luci/', { waitUntil: 'networkidle' });
	await page.locator('input[name="luci_username"]').fill(USER);
	await page.locator('input[name="luci_password"]').fill(PASS);
	await Promise.all([
		page.waitForNavigation({ waitUntil: 'networkidle' }),
		page.locator('button[type="submit"], .cbi-button-positive').first().click()
	]);
}

function installStub(payload) {
	const local = join(OUT, '.stub.sh');
	writeFileSync(local, "#!/bin/sh\ncat <<'H5FAN_STATUS_EOF'\n" + payload + 'H5FAN_STATUS_EOF\n');
	scp(local, STATUS_BIN);
	ssh('chmod 755 ' + STATUS_BIN);
	rmSync(local);
}

async function waitExpectation(exp, timeoutMs) {
	if (exp.healthClass !== undefined) {
		const want = exp.healthClass;
		await page.waitForFunction(cls => {
			const n = document.querySelector('#h5fan-health');
			return n && (cls === '' ? n.className === 'h5fan-health' : n.className.includes(cls));
		}, want, { timeout: timeoutMs });
	}
	if (exp.visible)
		await page.locator(exp.visible).waitFor({ state: 'visible', timeout: timeoutMs });
	if (exp.textIncludes) {
		const [sel, text] = exp.textIncludes;
		await page.waitForFunction(([s, t]) => {
			const n = document.querySelector(s);
			return n && n.textContent.includes(t);
		}, [sel, text], { timeout: timeoutMs });
	}
}

/* ---------------- run --------------------------------------------------- */
const results = [];
let backedUp = false;

try {
	await login();
	ssh('[ -f ' + BACKUP + ' ] || cp ' + STATUS_BIN + ' ' + BACKUP);
	backedUp = true;

	for (const sc of scenarios) {
		const item = { id: sc.id, name: sc.name, desc: sc.desc, ok: true, note: '', shots: [] };
		try {
			installStub(sc.payload);
			await page.goto(APP, { waitUntil: 'domcontentloaded' });
			await page.locator('.h5fan-hero').waitFor({ state: 'visible', timeout: 30000 });
			await page.waitForTimeout(2200);
			await waitExpectation(sc.expect, 10000);

			item.shots.push(await shot(sc.id + '-full'));
			for (const [suffix, sel] of [
				['health', '#h5fan-health'],
				['temps', '.h5fan-temp-grid'],
				['chart', '#h5fan-canvas-wrap'],
				['note', '#h5fan-safety-note']
			]) {
				const el = page.locator(sel).first();
				if (await el.isVisible().catch(() => false)) {
					await el.scrollIntoViewIfNeeded();
					item.shots.push(await shot(sc.id + '-' + suffix));
				}
			}
			const modem = page.locator('#h5fan-modem-setup');
			if (await modem.isVisible().catch(() => false))
				item.shots.push(await shot(sc.id + '-modem-setup'));
		} catch (e) {
			item.ok = false;
			item.note = String(e.message || e).split('\n')[0];
			item.shots.push(await shot(sc.id + '-FAILED'));
		}
		console.log((item.ok ? 'OK   ' : 'FAIL ') + sc.id + (item.note ? ' - ' + item.note : ''));
		results.push(item);
	}
} finally {
	if (backedUp) {
		const local = join(OUT, '.restore');
		scpFrom(BACKUP, local);
		scp(local, STATUS_BIN);
		ssh('chmod 755 ' + STATUS_BIN);
		rmSync(local);
		const restored = ssh('md5sum ' + STATUS_BIN).split(/\s/)[0];
		if (restored !== baseBackupMd5)
			console.error('WARNING: restored status binary md5 mismatch: ' + restored + ' != ' + baseBackupMd5);
		else
			console.log('status binary restored: ' + restored);
	}
	try {
		await page.goto(APP, { waitUntil: 'domcontentloaded' });
		await page.locator('.h5fan-hero').waitFor({ state: 'visible', timeout: 30000 });
		await page.waitForTimeout(2500);
		await shot('99-restored-full');
	} catch { /* best effort */ }
	await browser.close();
	rmSync(dirname(askpass), { recursive: true, force: true });
}

function scpFrom(remote, local) {
	const r = spawnSync('scp', ['-O', USER + '@' + HOST + ':' + remote, local],
		{ env: sshEnv, encoding: 'utf8', timeout: 30000 });
	if (r.status !== 0)
		throw new Error('scp from router failed: ' + remote);
}

/* ---------------- report ------------------------------------------------ */
const passed = results.filter(r => r.ok).length;
const html = `<!doctype html><html lang="ru"><head><meta charset="utf-8">
<title>H5000M fan control - failure states</title>
<style>
body{font-family:sans-serif;background:#14181d;color:#dde3ea;margin:24px;max-width:1200px}
h1{font-size:20px}h2{font-size:16px;margin-top:32px}
.scenario{border:1px solid #333a42;border-radius:10px;padding:14px 18px;margin:16px 0}
.ok{color:#7ee787}.bad{color:#ffa657;font-weight:bold}
img{max-width:520px;border:1px solid #444;margin:4px 8px 4px 0;vertical-align:top}
pre{background:#0d1117;border:1px solid #333a42;padding:8px;font-size:11px;max-height:180px;overflow:auto;white-space:pre-wrap}
small{color:#9aa4b0}
</style></head><body>
<h1>H5000M fan control - UI в состояниях отказа</h1>
<p>Router: <code>${BASE}</code> · сценариев пройдено: ${passed}/${results.length} · страница отрендерила каждое состояние на основе подменённого статус-скрипта (оригинал восстановлен).</p>
${results.map(r => `<div class="scenario"><h2>${r.id} · ${r.name} — <span class="${r.ok ? 'ok' : 'bad'}">${r.ok ? 'OK' : 'FAIL'}</span></h2>
<p>${r.desc}${r.note ? `<br><span class="bad">${r.note}</span>` : ''}</p>
${r.shots.map(s => `<a href="${s}"><img src="${s}"></a>`).join('')}
<details><summary>payload</summary><pre>${(scenarios.find(s => s.id === r.id) || {}).payload || ''}</pre></details>
</div>`).join('')}
<h2>JS-ошибки страницы</h2>
${problems.length ? `<pre>${problems.join('\n')}</pre>` : '<p class="ok">none</p>'}
</body></html>`;
writeFileSync(join(OUT, 'report.html'), html);
console.log('report: ' + join(OUT, 'report.html'));
process.exit(passed === results.length && !problems.length ? 0 : 1);
