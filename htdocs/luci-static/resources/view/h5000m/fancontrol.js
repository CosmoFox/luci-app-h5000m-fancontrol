'use strict';
'require view';
'require form';
'require fs';
'require poll';
'require ui';

var UPDATE_BIN = '/usr/share/h5000m-fancontrol/update.sh';
var UPDATE_RELEASE_URL = 'https://github.com/CosmoFox/luci-app-h5000m-fancontrol/releases/latest';

return view.extend({
	load: function() {
		return this.fetchStatus();
	},

	fetchStatus: function() {
		return fs.exec('/usr/sbin/h5000m-fancontrol-status').then(L.bind(function(res) {
			return this.parseStatus(res.stdout || '');
		}, this)).catch(function() {
			return {};
		});
	},

	parseStatus: function(text) {
		var data = {};
		text.trim().split(/\n/).forEach(function(line) {
			var pos = line.indexOf('=');
			if (pos > -1)
				data[line.substring(0, pos)] = line.substring(pos + 1);
		});
		return data;
	},

	fetchVersion: function() {
		return fs.exec(UPDATE_BIN, [ 'version' ]).then(L.bind(function(res) {
			var d = {}; try { d = JSON.parse((res && res.stdout) || '{}'); } catch (e) {}
			var node = document.getElementById('h5fan-build');
			if (node) {
				if (d.installed) {
					node.style.display = '';
					node.textContent = 'v' + d.installed;
				} else {
					node.style.display = 'none';
				}
			}
		}, this)).catch(L.bind(function(err) {
			console.info('h5fan: update.sh version failed: ' + (err && err.message ? err.message : err));
			var node = document.getElementById('h5fan-build');
			if (node) node.style.display = 'none';
		}, this));
	},

	toNum: function(value, fallback) {
		var n = parseInt(value, 10);
		return isNaN(n) ? fallback : n;
	},

	clamp: function(value, min, max) {
		return Math.max(min, Math.min(max, value));
	},

	setText: function(id, value) {
		var node = document.getElementById(id);
		if (node)
			node.textContent = value;
	},

	syncTitle: function(id) {
		var node = document.getElementById(id);
		if (node)
			node.title = node.textContent || '';
	},

	formatTemp: function(value) {
		return value !== undefined && value !== null && value !== '' ? _('%s °C').format(value) : _('Unavailable');
	},

	formatPwm: function(value) {
		var pwm = this.toNum(value, NaN);
		return isNaN(pwm) ? _('Unavailable') : _('%s / 255 · %s%%').format(pwm, Math.round(this.clamp(pwm, 0, 255) * 100 / 255));
	},

	modeName: function(mode) {
		if (mode === 'manual') return _('Manual');
		if (mode === 'kernel') return _('Kernel protection only');
		return _('Automatic');
	},

	profileName: function(profile) {
		if (profile === 'silent') return _('Quiet');
		if (profile === 'performance') return _('Performance');
		if (profile === 'custom') return _('Custom');
		return _('Balanced');
	},

	reasonName: function(reason) {
		var kernelFloor = (reason || '').indexOf('+kernel-floor') > -1;
		var floorOverride = (reason || '').indexOf('+floor-override') > -1;
		var base = (reason || '').replace('+kernel-floor', '').replace('+floor-override', '');
		var text;
		if (base === 'auto-down-delay') text = _('Waiting before speed down');
		else if (base === 'auto') text = _('Automatic curve');
		else if (base === 'manual') text = _('Manual request');
		else if (base === 'kernel') text = _('Kernel protection');
		else if (base === 'sensor-failsafe') text = _('Sensor failsafe');
		else if (base === 'curve-failsafe') text = _('Curve failsafe');
		else text = base || '-';
		if (floorOverride) return _('%s · ignoring firmware map').format(text);
		return kernelFloor ? _('%s · kernel safety floor').format(text) : text;
	},

	styleNode: function() {
		return E('style', {}, [
			'.h5fan{--fan-green:#36c98f;--fan-blue:#55a8ff;--fan-amber:#f0aa46;--fan-red:#ef6262}',
			'.h5fan-hero{display:flex;justify-content:space-between;align-items:center;gap:20px;padding:2px 2px 13px;margin:0 0 14px;border-bottom:1px solid var(--border-color-low,#e8e8e8)}',
			'.h5fan-hero h2{margin:0 0 4px;font-size:22px;line-height:1.3}.h5fan-hero p{margin:0;color:var(--text-color-medium,#666);font-size:13px}',
			'.h5fan-health{display:inline-flex;align-items:center;gap:7px;padding:5px 9px;border-radius:999px;font-size:12px;font-weight:600;white-space:nowrap;background:var(--background-color-high,#f5f5f5);color:var(--fan-green)}',
			'.h5fan-health:before{content:"";width:7px;height:7px;border-radius:50%;background:currentColor}',
			'.h5fan-health.warn{color:var(--fan-amber)}.h5fan-health.fail{color:var(--fan-red)}',
			'.h5fan-grid{display:grid;grid-template-columns:repeat(4,minmax(145px,1fr));gap:12px;margin-bottom:16px}',
			'.h5fan-card{position:relative;overflow:hidden;min-height:88px;padding:14px;border:1px solid var(--border-color-medium,#d8d8d8);border-radius:10px;background:var(--background-color-high,#fff)}',
			'.h5fan-card.primary{border-color:rgba(54,201,143,.45);background:linear-gradient(160deg,rgba(54,201,143,.12),rgba(54,201,143,.025))}',
			'.h5fan-card-title{font-size:12px;color:var(--text-color-medium,#666);margin-bottom:8px}.h5fan-card-value{font-size:21px;font-weight:650;line-height:1.2;color:var(--text-color-high,#222)}',
			'.h5fan-card-hint{font-size:11px;color:var(--text-color-low,#888);margin-top:7px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
			'.h5fan-card.temperatures{grid-column:span 4;padding-bottom:12px}.h5fan-temp-head{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:8px}.h5fan-temp-head .h5fan-card-title{margin:0}.h5fan-temp-source{font-size:11px;color:var(--fan-blue);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
			'.h5fan-temp-grid{display:grid;grid-template-columns:repeat(4,minmax(86px,1fr));gap:8px}',
			'.h5fan-temp-item{position:relative;min-width:0;padding:8px 10px;border-radius:8px;background:rgba(127,127,127,.055)}',
			'.h5fan-temp-label{display:flex;align-items:center;justify-content:space-between;gap:6px;font-size:11px;color:var(--text-color-medium,#777)}',
			'.h5fan-temp-name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
			'.h5fan-temp-badge{display:none;flex:none;padding:1px 6px;border-radius:999px;font-size:9px;font-weight:600;background:rgba(85,168,255,.16);color:var(--fan-blue)}',
			'.h5fan-temp-item.active .h5fan-temp-badge{display:inline-block}',
			'.h5fan-build{padding-left:5px;font-size:10px;color:var(--text-color-medium,#777);opacity:.6}',
			'.h5fan-temp-item.active{background:rgba(85,168,255,.11);box-shadow:inset 0 0 0 1px rgba(85,168,255,.32)}.h5fan-temp-item.active .h5fan-temp-label{color:var(--fan-blue)}',
			'.h5fan-temp-value{margin-top:4px;font-size:17px;font-weight:650;color:var(--text-color-high,#222);white-space:nowrap}.h5fan-temp-hint{margin-top:3px;font-size:10px;color:var(--text-color-low,#888);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
			'.h5fan-section{margin:0 0 16px;padding:16px;border:1px solid var(--border-color-medium,#d8d8d8);border-radius:12px;background:var(--background-color-high,#fff)}',
			'.h5fan-section-head{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:12px}.h5fan-section h3{margin:0}',
			'.h5fan-badge{padding:4px 8px;border-radius:6px;background:rgba(85,168,255,.12);color:var(--fan-blue);font-size:11px;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
			'.h5fan-curve-layout{display:grid;grid-template-columns:minmax(260px,1fr) 190px;gap:14px}',
			'.h5fan-canvas-wrap{position:relative;aspect-ratio:2.9/1;min-height:170px;max-height:330px;border:1px solid rgba(54,201,143,.16);border-radius:12px;overflow:hidden}.h5fan-canvas{width:100%;height:100%;display:block}',
			'.h5fan-side{display:grid;gap:10px;grid-template-rows:repeat(3,1fr)}',
			'.h5fan-chip{display:flex;flex-direction:column;justify-content:center;min-height:0;overflow:hidden;padding:11px;border:1px solid var(--border-color-low,#ddd);border-radius:8px;background:rgba(127,127,127,.045)}',
			'.h5fan-chip span{display:block;font-size:11px;color:var(--text-color-medium,#777);margin-bottom:5px}.h5fan-chip strong{font-size:18px}',
			'.h5fan-chip strong.h5fan-reason{font-size:13px;line-height:1.35;min-height:2.7em;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;overflow-wrap:anywhere}',
			'.h5fan-note{margin-top:12px;padding:10px 12px;border-left:3px solid var(--fan-blue);background:rgba(85,168,255,.07);color:var(--text-color-medium,#666);font-size:12px}',
			'.h5fan-legend{display:flex;flex-wrap:wrap;gap:6px 16px;margin-top:12px;font-size:11px;color:var(--text-color-medium,#777)}',
			'.h5fan-legend .sw{display:inline-block;vertical-align:middle;margin-right:6px}.h5fan-legend .sw-curve{width:16px;height:0;border-top:3px solid var(--fan-green);border-radius:2px}.h5fan-legend .sw-floor{width:16px;height:0;border-top:2px dashed var(--fan-amber)}',
			'.h5fan-legend .sw-applied{width:9px;height:9px;border-radius:50%;background:var(--fan-blue);box-shadow:0 0 0 3px rgba(85,168,255,.22)}.h5fan-legend .sw-hyst{width:14px;height:10px;border-radius:3px;background:rgba(85,168,255,.14);box-shadow:inset 0 0 0 1px rgba(85,168,255,.35)}',
			'.h5fan-slider{display:flex;align-items:center;gap:10px;max-width:480px}.h5fan-slider input[type=range]{flex:1;min-width:190px}.h5fan-slider input[type=number]{width:84px}',
			'.h5fan-update{display:grid;gap:10px}.h5fan-update-buttons{display:flex;flex-wrap:wrap;gap:10px;align-items:center}.h5fan-update a.cbi-button{color:var(--text-color-high,#222);text-decoration:none}.h5fan-update-meta{font-size:12px;color:var(--text-color-medium,#666)}.h5fan-update-meta strong{color:var(--text-color-high,#222)}.h5fan-update-beta{margin-top:6px;padding-top:10px;border-top:1px dashed var(--border-color-low,#ddd)}.h5fan-update-checkbox{display:inline-flex;align-items:center;gap:8px;font-size:13px;cursor:pointer}.h5fan-update-warn{margin-top:8px;padding:8px 10px;border-left:3px solid var(--fan-amber);background:rgba(240,170,70,.1);color:var(--text-color-medium,#666);font-size:12px}',
			'@media(max-width:1050px){.h5fan-grid{grid-template-columns:repeat(2,minmax(145px,1fr))}.h5fan-card.temperatures{grid-column:span 2}.h5fan-temp-grid{grid-template-columns:repeat(4,minmax(72px,1fr))}}',
			'@media(max-width:750px){.h5fan-curve-layout{grid-template-columns:1fr}.h5fan-side{grid-template-columns:repeat(3,1fr);grid-template-rows:1fr}}',
			'@media(max-width:520px){.h5fan-hero{display:block}.h5fan-health{margin-top:12px}}',
			'@media(max-width:520px){.h5fan-grid{grid-template-columns:1fr}.h5fan-card.temperatures{grid-column:span 1}.h5fan-temp-grid{grid-template-columns:repeat(2,minmax(110px,1fr))}.h5fan-side{grid-template-columns:1fr;grid-template-rows:repeat(3,1fr)}.h5fan-slider{align-items:stretch;flex-direction:column}.h5fan-slider input[type=range]{width:100%;min-width:0}}'
		].join(''));
	},

	card: function(id, title, primary) {
		return E('div', { 'class': 'h5fan-card' + (primary ? ' primary' : '') }, [
			E('div', { 'class': 'h5fan-card-title', id: id + '-title' }, title),
			E('div', { 'class': 'h5fan-card-value', id: id + '-value' }, _('Loading…')),
			E('div', { 'class': 'h5fan-card-hint', id: id + '-hint' }, '')
		]);
	},

	temperatureItem: function(id, title) {
		return E('div', { 'class': 'h5fan-temp-item', id: id }, [
			E('div', { 'class': 'h5fan-temp-label' }, [
				E('span', { 'class': 'h5fan-temp-name' }, title),
				E('span', { 'class': 'h5fan-temp-badge' }, _('Priority'))
			]),
			E('div', { 'class': 'h5fan-temp-value', id: id + '-value' }, _('Loading…')),
			E('div', { 'class': 'h5fan-temp-hint', id: id + '-hint' }, '')
		]);
	},

	temperatureCard: function() {
		return E('div', { 'class': 'h5fan-card temperatures' }, [
			E('div', { 'class': 'h5fan-temp-head' }, [
				E('div', { 'class': 'h5fan-card-title' }, _('Temperature')),
				E('div', { 'class': 'h5fan-temp-source', id: 'h5fan-temp-source' }, '')
			]),
			E('div', { 'class': 'h5fan-temp-grid' }, [
				this.temperatureItem('h5fan-cpu', _('CPU')),
				this.temperatureItem('h5fan-phy', _('Ethernet PHY')),
				this.temperatureItem('h5fan-wifi', _('Wi-Fi radios')),
				this.temperatureItem('h5fan-modem', _('5G modem'))
			])
		]);
	},

	statusPanel: function() {
		return E('div', {}, [
			E('div', { 'class': 'h5fan-hero' }, [
				E('div', {}, [
					E('h2', [ _('Cooling management'), E('span', { 'class': 'h5fan-build', id: 'h5fan-build' }, '') ]),
					E('p', _('Automatically balances cooling and noise based on device temperatures.'))
				]),
				E('div', { 'class': 'h5fan-health', id: 'h5fan-health' }, _('Checking…'))
			]),
			E('div', { 'class': 'h5fan-grid' }, [
				this.temperatureCard()
			])
		]);
	},

	parseCurve: function(text) {
		var points = [];
		(text || '').split(',').forEach(function(pair) {
			var parts = pair.split(':'), temp = parseInt(parts[0], 10), percent = parseInt(parts[1], 10);
			if (parts.length === 2 && !isNaN(temp) && !isNaN(percent))
				points.push({ temp: temp, percent: percent });
		});
		return points;
	},

	chartColor: function(str) {
		str = (str || '').trim();
		var m = /^#([0-9a-f]{3})$/i.exec(str), s;
		if (m) {
			s = m[1];
			return [parseInt(s.charAt(0) + s.charAt(0), 16), parseInt(s.charAt(1) + s.charAt(1), 16), parseInt(s.charAt(2) + s.charAt(2), 16)];
		}
		m = /^#([0-9a-f]{6})$/i.exec(str);
		if (m) {
			s = m[1];
			return [parseInt(s.substring(0, 2), 16), parseInt(s.substring(2, 4), 16), parseInt(s.substring(4, 6), 16)];
		}
		m = /rgba?\(([^)]+)\)/i.exec(str);
		if (m) {
			var p = m[1].split(',');
			return [this.toNum(p[0], 255), this.toNum(p[1], 255), this.toNum(p[2], 255)];
		}
		return [255, 255, 255];
	},

	chartRgba: function(str, a) {
		var c = this.chartColor(str);
		return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')';
	},

	chartLum: function(str) {
		var c = this.chartColor(str);
		return (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;
	},

	chartPalette: function(canvas) {
		var cs = getComputedStyle(canvas);
		function v(name, fb) { var s = cs.getPropertyValue(name); s = (s || '').trim(); return s || fb; }
		var panel = v('--background-color-high', '#ffffff');
		return {
			dark: this.chartLum(panel) < 0.45,
			panel: panel,
			green: v('--fan-green', '#36c98f'),
			blue: v('--fan-blue', '#55a8ff'),
			amber: v('--fan-amber', '#f0aa46'),
			red: v('--fan-red', '#ef6262'),
			medium: v('--text-color-medium', '#666666'),
			low: v('--text-color-low', '#888888'),
			high: v('--text-color-high', '#222222')
		};
	},

	curveAt: function(points, temp) {
		if (!points.length) return NaN;
		if (temp <= points[0].temp) return points[0].percent;
		for (var i = 1; i < points.length; i++) {
			if (temp <= points[i].temp) {
				var a = points[i - 1], b = points[i];
				if (b.temp === a.temp) return b.percent;
				return a.percent + (b.percent - a.percent) * (temp - a.temp) / (b.temp - a.temp);
			}
		}
		return points[points.length - 1].percent;
	},

	floorAt: function(levels, temp) {
		var value = 0;
		for (var i = 0; i < levels.length; i++)
			if (temp >= levels[i].temp) value = levels[i].pwm;
		return value;
	},

	chartColorForTemp: function(P, temp) {
		return temp < 60 ? P.green : (temp < 80 ? P.amber : P.red);
	},

	chartRoundRect: function(ctx, x, y, w, h, r) {
		ctx.beginPath();
		ctx.moveTo(x + r, y);
		ctx.arcTo(x + w, y, x + w, y + h, r);
		ctx.arcTo(x + w, y + h, x, y + h, r);
		ctx.arcTo(x, y + h, x, y, r);
		ctx.arcTo(x, y, x + w, y, r);
		ctx.closePath();
	},

	chartUpdate: function(data) {
		this.chartData = data;
		var ct = this.toNum(data.control_temp, NaN);
		var req = this.toNum(data.requested_pwm, NaN);
		var app = this.toNum(data.applied_pwm, this.toNum(data.pwm_value, NaN));
		var target = (isNaN(ct) || isNaN(req) || isNaN(app)) ? null : { ct: ct, req: req * 100 / 255, app: app * 100 / 255 };
		var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
		if (!target || !this.chartMarker || reduced) {
			this.chartMarker = target;
			this.chartTarget = target;
			if (this.chartRaf) { window.cancelAnimationFrame(this.chartRaf); this.chartRaf = 0; }
			this.chartDraw();
			return;
		}
		this.chartFrom = { ct: this.chartMarker.ct, req: this.chartMarker.req, app: this.chartMarker.app };
		this.chartTarget = target;
		this.chartAnimStart = 0;
		if (!this.chartRaf) {
			if (!this.chartTickFn)
				this.chartTickFn = L.bind(function(ts) { this.chartTick(ts); }, this);
			this.chartRaf = window.requestAnimationFrame(this.chartTickFn);
		}
	},

	chartTick: function(ts) {
		if (!this.chartAnimStart) this.chartAnimStart = ts;
		var p = this.clamp((ts - this.chartAnimStart) / 320, 0, 1);
		var e = 1 - Math.pow(1 - p, 3);
		var f = this.chartFrom, t = this.chartTarget;
		this.chartMarker = { ct: f.ct + (t.ct - f.ct) * e, req: f.req + (t.req - f.req) * e, app: f.app + (t.app - f.app) * e };
		this.chartDraw();
		if (p < 1) {
			this.chartRaf = window.requestAnimationFrame(this.chartTickFn);
		} else {
			this.chartRaf = 0;
			this.chartMarker = this.chartTarget;
			this.chartDraw();
		}
	},

	chartDraw: function() {
		var canvas = document.getElementById('h5fan-curve');
		if (!canvas || !this.chartData) return;
		var self = this;
		var data = this.chartData, points = this.parseCurve(data.curve_data);
		var w = canvas.clientWidth || 600, h = canvas.clientHeight || 220;
		var ratio = window.devicePixelRatio || 1;
		var bw = Math.round(w * ratio), bh = Math.round(h * ratio);
		if (canvas.width !== bw || canvas.height !== bh) { canvas.width = bw; canvas.height = bh; }
		var ctx = canvas.getContext('2d');
		ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
		var P = this.chartPalette(canvas);
		function R(str, a) { return self.chartRgba(str, a); }
		var minT = 20, maxT = 110;
		var font = 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
		var narrow = w < 460;
		var left = narrow ? 30 : 38, right = narrow ? 10 : 16, top = 16, bottom = narrow ? 22 : 26;
		var plotW = w - left - right, plotH = h - top - bottom;
		if (plotW < 40 || plotH < 40) return;
		function X(t) { return left + Math.max(0, Math.min(1, (t - minT) / (maxT - minT))) * plotW; }
		function Y(p) { return top + (100 - Math.max(0, Math.min(100, p))) / 100 * plotH; }

		ctx.clearRect(0, 0, w, h);
		ctx.fillStyle = P.panel;
		ctx.fillRect(0, 0, w, h);
		var tint = ctx.createLinearGradient(0, 0, 0, h);
		tint.addColorStop(0, R(P.green, P.dark ? 0.07 : 0.05));
		tint.addColorStop(1, R(P.green, P.dark ? 0.015 : 0.012));
		ctx.fillStyle = tint;
		ctx.fillRect(0, 0, w, h);

		var yTicks = plotH < 130 ? [0, 50, 100] : [0, 25, 50, 75, 100];
		ctx.font = (narrow ? 9 : 10) + 'px ' + font;
		ctx.textAlign = 'right';
		ctx.textBaseline = 'middle';
		yTicks.forEach(function(level) {
			var y = Y(level);
			ctx.strokeStyle = R(P.medium, (level === 0 || level === 100) ? 0.30 : 0.14);
			ctx.lineWidth = 1;
			ctx.beginPath();
			ctx.moveTo(left, y);
			ctx.lineTo(left + plotW, y);
			ctx.stroke();
			ctx.fillStyle = P.low;
			ctx.fillText(level + '%', left - 6, y);
		});

		var pxPerDeg = plotW / (maxT - minT);
		var stepChoices = [10, 15, 20, 30], step = 30;
		for (var si = 0; si < stepChoices.length; si++) {
			if (stepChoices[si] * pxPerDeg >= 52) { step = stepChoices[si]; break; }
		}
		ctx.textAlign = 'center';
		ctx.textBaseline = 'top';
		for (var t = Math.ceil(minT / step) * step; t <= maxT; t += step) {
			var gx = X(t);
			ctx.strokeStyle = R(P.medium, 0.08);
			ctx.lineWidth = 1;
			ctx.beginPath();
			ctx.moveTo(gx, top);
			ctx.lineTo(gx, top + plotH);
			ctx.stroke();
			ctx.fillStyle = P.low;
			ctx.fillText(t + '°', gx, top + plotH + 7);
		}

		if (points.length < 2) {
			ctx.fillStyle = P.low;
			ctx.font = '12px ' + font;
			ctx.textAlign = 'center';
			ctx.textBaseline = 'middle';
			ctx.fillText('No curve data', left + plotW / 2, top + plotH / 2);
			return;
		}

		var m = this.chartMarker;
		var ct = m ? m.ct : this.toNum(data.control_temp, NaN);
		var hyst = this.toNum(data.hysteresis, 0);
		if (data.mode === 'auto' && hyst > 0 && !isNaN(ct)) {
			var bx = X(ct), bw2 = X(ct + hyst) - bx;
			ctx.fillStyle = R(P.blue, 0.09);
			ctx.fillRect(bx, top, bw2, plotH);
			ctx.strokeStyle = R(P.blue, 0.35);
			ctx.lineWidth = 1;
			ctx.setLineDash([2, 3]);
			ctx.beginPath();
			ctx.moveTo(bx + bw2, top);
			ctx.lineTo(bx + bw2, top + plotH);
			ctx.stroke();
			ctx.setLineDash([]);
		}

		var levels = this.parseFloors(data.kernel_floor_levels);
		if (levels.length) {
			var samples = [], st;
			for (st = minT; st <= maxT; st += 2) {
				var cv = this.curveAt(points, st), fv = this.floorAt(levels, st) * 100 / 255;
				samples.push({ t: st, cv: cv, env: Math.max(cv, fv) });
			}
			ctx.beginPath();
			samples.forEach(function(s, i) { if (i) ctx.lineTo(X(s.t), Y(s.env)); else ctx.moveTo(X(s.t), Y(s.env)); });
			for (var i2 = samples.length - 1; i2 >= 0; i2--) ctx.lineTo(X(samples[i2].t), Y(samples[i2].cv));
			ctx.closePath();
			ctx.fillStyle = R(P.amber, P.dark ? 0.16 : 0.12);
			ctx.fill();

			ctx.strokeStyle = R(P.amber, 0.85);
			ctx.lineWidth = 2;
			ctx.setLineDash([6, 4]);
			var prevT = minT, prevV = this.floorAt(levels, minT) * 100 / 255;
			for (var li = 0; li < levels.length; li++) {
				var segEnd = Math.min(levels[li].temp, maxT);
				if (prevV > 0 && segEnd > prevT) {
					ctx.beginPath();
					ctx.moveTo(X(prevT), Y(prevV));
					ctx.lineTo(X(segEnd), Y(prevV));
					ctx.stroke();
				}
				prevT = levels[li].temp;
				prevV = levels[li].pwm * 100 / 255;
				if (li === levels.length - 1 && prevV > 0 && maxT > prevT) {
					ctx.beginPath();
					ctx.moveTo(X(prevT), Y(prevV));
					ctx.lineTo(X(maxT), Y(prevV));
					ctx.stroke();
				}
			}
			ctx.setLineDash([]);
		}

		ctx.beginPath();
		ctx.moveTo(X(points[0].temp), top + plotH);
		points.forEach(function(p) { ctx.lineTo(X(p.temp), Y(p.percent)); });
		ctx.lineTo(X(points[points.length - 1].temp), top + plotH);
		ctx.closePath();
		var area = ctx.createLinearGradient(0, top, 0, top + plotH);
		area.addColorStop(0, R(P.green, P.dark ? 0.20 : 0.26));
		area.addColorStop(1, R(P.green, 0.02));
		ctx.fillStyle = area;
		ctx.fill();

		var stroke = ctx.createLinearGradient(X(minT), 0, X(maxT), 0);
		stroke.addColorStop(0, P.green);
		stroke.addColorStop(0.5, P.green);
		stroke.addColorStop(0.72, P.amber);
		stroke.addColorStop(1, P.red);
		ctx.beginPath();
		points.forEach(function(p, index) { if (index) ctx.lineTo(X(p.temp), Y(p.percent)); else ctx.moveTo(X(p.temp), Y(p.percent)); });
		ctx.save();
		ctx.strokeStyle = stroke;
		ctx.lineWidth = narrow ? 2.5 : 3;
		ctx.lineJoin = 'round';
		ctx.lineCap = 'round';
		ctx.shadowColor = R(P.green, P.dark ? 0.35 : 0.22);
		ctx.shadowBlur = 8;
		ctx.stroke();
		ctx.restore();

		points.forEach(function(p) {
			ctx.beginPath();
			ctx.arc(X(p.temp), Y(p.percent), narrow ? 2.5 : 3, 0, Math.PI * 2);
			ctx.fillStyle = P.panel;
			ctx.fill();
			ctx.strokeStyle = self.chartColorForTemp(P, p.temp);
			ctx.lineWidth = 2;
			ctx.stroke();
		});

		if (m && !isNaN(m.ct)) {
			var mx = X(m.ct), myReq = Y(m.req), myApp = Y(m.app);
			ctx.strokeStyle = R(P.medium, 0.40);
			ctx.lineWidth = 1;
			ctx.setLineDash([3, 3]);
			ctx.beginPath();
			ctx.moveTo(mx, top);
			ctx.lineTo(mx, top + plotH);
			ctx.stroke();
			ctx.strokeStyle = R(P.blue, 0.65);
			ctx.lineWidth = 1.5;
			ctx.setLineDash([4, 4]);
			ctx.beginPath();
			ctx.moveTo(left, myApp);
			ctx.lineTo(mx, myApp);
			ctx.stroke();
			ctx.setLineDash([]);

			ctx.font = '600 ' + (narrow ? 9 : 10) + 'px ' + font;
			ctx.textAlign = 'left';
			ctx.textBaseline = 'bottom';
			var guideLabel = Math.round(m.app) + '%';
			ctx.lineWidth = 3;
			ctx.strokeStyle = P.panel;
			ctx.strokeText(guideLabel, left + 4, myApp - 3);
			ctx.fillStyle = P.blue;
			ctx.fillText(guideLabel, left + 4, myApp - 3);

			if (Math.abs(myReq - myApp) > 0.5) {
				ctx.strokeStyle = R(P.blue, 0.85);
				ctx.lineWidth = 3;
				ctx.lineCap = 'round';
				ctx.beginPath();
				ctx.moveTo(mx, myReq);
				ctx.lineTo(mx, myApp);
				ctx.stroke();
			}

			var tf = this.toNum(data.thermal_floor, 0);
			if (tf > 0) {
				ctx.beginPath();
				ctx.arc(mx, Y(tf * 100 / 255), 3, 0, Math.PI * 2);
				ctx.fillStyle = P.amber;
				ctx.fill();
				ctx.strokeStyle = P.panel;
				ctx.lineWidth = 1.5;
				ctx.stroke();
			}

			ctx.beginPath();
			ctx.arc(mx, myReq, 4.5, 0, Math.PI * 2);
			ctx.fillStyle = P.panel;
			ctx.fill();
			ctx.strokeStyle = P.green;
			ctx.lineWidth = 2.5;
			ctx.stroke();

			ctx.beginPath();
			ctx.arc(mx, myApp, 9, 0, Math.PI * 2);
			ctx.fillStyle = R(P.blue, 0.18);
			ctx.fill();
			ctx.beginPath();
			ctx.arc(mx, myApp, 5, 0, Math.PI * 2);
			ctx.fillStyle = P.blue;
			ctx.fill();
			ctx.strokeStyle = P.panel;
			ctx.lineWidth = 2;
			ctx.stroke();

			if (!narrow) {
				var delta = Math.round(m.app) - Math.round(m.req);
				var text = Math.round(m.ct) + '°C · ' + (delta > 0 ? Math.round(m.req) + '% → ' + Math.round(m.app) + '%' : Math.round(m.app) + '%');
				if (data.fan_feedback === '1' && data.fan_rpm) text += ' · ' + data.fan_rpm + ' RPM';
				ctx.font = '600 10px ' + font;
				var tw = ctx.measureText(text).width + 16;
				var tx = this.clamp(mx - tw / 2, 6, w - tw - 6);
				var ty = this.clamp(myApp - 34, 6, h - 30);
				this.chartRoundRect(ctx, tx, ty, tw, 21, 6);
				ctx.fillStyle = P.dark ? 'rgba(240,246,244,.95)' : 'rgba(36,52,45,.94)';
				ctx.fill();
				ctx.fillStyle = P.dark ? '#1c2422' : '#ffffff';
				ctx.textAlign = 'left';
				ctx.textBaseline = 'middle';
				ctx.fillText(text, tx + 8, ty + 11);
			}
		}
	},

	curvePanel: function() {
		return E('div', { 'class': 'h5fan-section' }, [
			E('div', { 'class': 'h5fan-section-head' }, [ E('h3', _('Effective fan policy')), E('span', { 'class': 'h5fan-badge', id: 'h5fan-profile' }, '-') ]),
			E('div', { 'class': 'h5fan-curve-layout' }, [
				E('div', { 'class': 'h5fan-canvas-wrap', id: 'h5fan-canvas-wrap' }, [
					E('canvas', { 'class': 'h5fan-canvas', id: 'h5fan-curve' })
				]),
				E('div', { 'class': 'h5fan-side' }, [
					E('div', { 'class': 'h5fan-chip' }, [ E('span', _('Requested output')), E('strong', { id: 'h5fan-requested' }, '-') ]),
					E('div', { 'class': 'h5fan-chip' }, [ E('span', _('Applied output')), E('strong', { id: 'h5fan-applied' }, '-') ]),
					E('div', { 'class': 'h5fan-chip' }, [ E('span', _('Policy reason')), E('strong', { 'class': 'h5fan-reason', id: 'h5fan-reason' }, '-') ])
				])
			]),
			E('div', { 'class': 'h5fan-legend' }, [
				E('span', {}, [ E('i', { 'class': 'sw sw-curve' }), _('Fan curve') ]),
				E('span', {}, [ E('i', { 'class': 'sw sw-floor' }), _('Kernel safety floor') ]),
				E('span', {}, [ E('i', { 'class': 'sw sw-applied' }), _('Applied output') ]),
				E('span', {}, [ E('i', { 'class': 'sw sw-hyst' }), _('Hysteresis window') ])
			]),
			E('div', { 'class': 'h5fan-note', id: 'h5fan-safety-note' }, _('Kernel thermal protection is always retained. Requested output may be raised automatically when the kernel requires more cooling.'))
		]);
	},

	parseFloors: function(text) {
		var out = [];
		(text || '').split(',').forEach(function(pair) {
			var parts = pair.split('='), temp = parseInt(parts[0], 10), pwm = parseInt(parts[1], 10);
			if (parts.length === 2 && !isNaN(temp) && !isNaN(pwm))
				out.push({ temp: temp, pwm: pwm });
		});
		out.sort(function(a, b) { return a.temp - b.temp; });
		return out;
	},

	formatFloorLevels: function(text) {
		return this.parseFloors(text).map(function(level) {
			return level.temp + ' °C → ' + Math.round(level.pwm * 100 / 255) + '%';
		});
	},

	updateStatus: function(data) {
		var pwm = this.toNum(data.pwm_value, NaN);
		var age = this.toNum(data.state_age, NaN), interval = this.toNum(data.interval, 5), health = document.getElementById('h5fan-health');
		var requested = this.toNum(data.requested_pwm, NaN), applied = this.toNum(data.applied_pwm || data.pwm_value, NaN);
		this.lastStatus = data;
		this.setText('h5fan-temp-source', _('Current input: %s').format((data.control_sensor || _('No valid sensor')) + ' · ' + this.formatTemp(data.control_temp)));
		['cpu', 'phy', 'wifi', 'modem'].forEach(function(name) {
			var node = document.getElementById('h5fan-' + name);
			var active = name === 'cpu' && data.control_sensor === data.cpu_label ||
				name === 'phy' && data.control_sensor === data.phy_label ||
				name === 'wifi' && (data.control_sensor === data.wifi1_label || data.control_sensor === data.wifi2_label) ||
				name === 'modem' && data.control_sensor === '5G modem';
			if (node) node.classList.toggle('active', !!active);
		});
		var floorLevels = this.formatFloorLevels(data.kernel_floor_levels);
		if (data.thermal_owner === 'userspace') {
			this.setText('h5fan-safety-note', _('The fan manager has exclusive fan policy control. Kernel CPU throttling and hot/critical over-temperature protection remain active.'));
		} else if (floorLevels.length) {
			this.setText('h5fan-safety-note', _('Firmware fan map: %s. Install patched firmware for full curve control.').format(floorLevels.join(' · ')));
		} else {
			this.setText('h5fan-safety-note', _('Kernel thermal protection is always retained. Requested output may be raised automatically when the kernel requires more cooling.'));
		}
		this.setText('h5fan-cpu-value', this.formatTemp(data.cpu_temp)); this.setText('h5fan-cpu-hint', data.cpu_label || '');
		this.setText('h5fan-phy-value', this.formatTemp(data.phy_temp)); this.setText('h5fan-phy-hint', data.phy_label || '');
		this.setText('h5fan-wifi-value', data.wifi1_temp || data.wifi2_temp ? [data.wifi1_temp, data.wifi2_temp].filter(Boolean).join(' / ') + ' °C' : _('Unavailable'));
		this.setText('h5fan-wifi-hint', [data.wifi1_label, data.wifi2_label].filter(Boolean).join(' · '));
		this.setText('h5fan-modem-value', this.formatTemp(data.module_temp)); this.setText('h5fan-modem-hint', data.module_name || _('From the local modem cache'));
		this.setText('h5fan-profile', this.modeName(data.mode) + (data.mode === 'auto' ? ' · ' + this.profileName(data.curve) : ''));
		this.syncTitle('h5fan-profile');
		this.setText('h5fan-requested', isNaN(requested) ? '-' : Math.round(requested * 100 / 255) + '%');
		this.setText('h5fan-applied', isNaN(applied) ? (isNaN(pwm) ? '-' : Math.round(pwm * 100 / 255) + '%') : Math.round(applied * 100 / 255) + '%');
		this.setText('h5fan-reason', this.reasonName(data.reason));
		this.syncTitle('h5fan-reason');
		if (health) {
			health.className = 'h5fan-health';
			if (data.result === 'failsafe') { health.className += ' fail'; health.textContent = _('Failsafe cooling'); }
			else if (isNaN(age) || age > interval * 3 + 5) { health.className += ' warn'; health.textContent = _('Status delayed'); }
			else { health.textContent = _('Running normally'); }
		}
		this.chartUpdate(data);
	},

	validateCurve: function(sectionId, value) {
		var points = this.parseCurve(value), last = -1;
		if (points.length < 2 || points.map(function(p) { return p.temp + ':' + p.percent; }).join(',') !== value.replace(/\s+/g, ''))
			return _('Use comma-separated temperature:percent points, for example 35:0,45:50,70:80,90:100.');
		for (var i = 0; i < points.length; i++) {
			if (points[i].temp <= last || points[i].temp < 0 || points[i].temp > 150 || points[i].percent < 0 || points[i].percent > 100)
				return _('Temperatures must increase from 0–150 °C and percentages must be 0–100.');
			last = points[i].temp;
		}
		return true;
	},

	updSet: function(id, txt) {
		this.setText(id, txt);
	},

	updSetVer: function(id, label, ver) {
		var node = document.getElementById(id);
		if (!node) return;
		node.textContent = '';
		node.appendChild(document.createTextNode(label + ': '));
		node.appendChild(E('strong', {}, ver));
	},

	updShow: function(id, show) {
		var node = document.getElementById(id);
		if (node) node.style.display = show ? '' : 'none';
	},

	updErrText: function(error, fallback) {
		if (error === 'asset_pending')
			return _('The update is still building on the server. Please wait about 15-20 minutes and try again.');
		if (error === 'Could not reach GitHub')
			return _('Could not check for updates. Please check the router\'s internet access.');
		if (error === 'unknown_current_release')
			return _('The installed release was not identified. Install a version through the Update tab first.');
		return error || fallback;
	},

	updBusy: function(busy) {
		var bi = document.getElementById('h5fan-upd-install'), bc = document.getElementById('h5fan-upd-check'),
			bb = document.getElementById('h5fan-upd-install-beta'), br = document.getElementById('h5fan-upd-reinstall');
		if (bi) bi.disabled = busy;
		if (bc) bc.disabled = busy;
		if (bb) bb.disabled = busy;
		if (br) br.disabled = busy;
	},

	checkUpdate: function() {
		this.updSet('h5fan-upd-status', _('Checking the latest release…'));
		this.updShow('h5fan-upd-install', false);
		this.updShow('h5fan-upd-install-beta', false);
		var b = document.getElementById('h5fan-upd-check'); if (b) b.disabled = true;
		var args = [ 'check' ];
		if (document.getElementById('h5fan-upd-beta') && document.getElementById('h5fan-upd-beta').checked)
			args.push('beta');
		return fs.exec(UPDATE_BIN, args).then(L.bind(function(res) {
			var d = {}; try { d = JSON.parse((res && res.stdout) || '{}'); } catch (e) {}
			this.updSet('h5fan-upd-current', d.current || '—');
			var latest = String(d.latest || '').replace(/^v/i, '');
			var betaOn = !!(document.getElementById('h5fan-upd-beta') && document.getElementById('h5fan-upd-beta').checked);
			if (d.release_url) { var a = document.getElementById('h5fan-upd-release'); if (a) { a.href = d.release_url; a.style.display = ''; } }
			this.updateBeta(d);
			if (!d.success) {
				this.updSet('h5fan-upd-status', this.updErrText(d.error, _('Could not check for updates')));
			} else if (d.update_available == 1 || d.update_available === true) {
				this.updShow('h5fan-upd-install', true);
				this.updSetVer('h5fan-upd-status', _('Update available'), latest || '—');
			} else if (betaOn && d.beta_latest) {
				if (d.beta_available == 1 || d.beta_available === true)
					this.updSet('h5fan-upd-status', _('Beta update available: %s').format(String(d.beta_latest).replace(/^v/i, '')));
				else
					this.updSet('h5fan-upd-status', _('You have the latest beta'));
			} else if (!d.latest) {
				this.updSet('h5fan-upd-status', betaOn ? _('No beta releases found') : _('No stable release published yet.'));
			} else {
				this.updSet('h5fan-upd-status', _('You have the latest version'));
			}
		}, this), L.bind(function(err) {
			console.info('h5fan: update check failed: ' + (err.message || err));
			this.updSet('h5fan-upd-status', _('Could not check for updates') + ' ' + (err.message || err));
		}, this)).then(L.bind(function() {
			var b = document.getElementById('h5fan-upd-check'); if (b) b.disabled = false;
		}, this));
	},

	updateBeta: function(d, on) {
		var box = document.getElementById('h5fan-upd-beta');
		on = (on !== undefined) ? on : !!(box && box.checked);
		this.updShow('h5fan-upd-beta-warn', on);
		var wrap = document.getElementById('h5fan-upd-beta-wrap');
		if (wrap) wrap.style.display = on ? '' : 'none';
		if (!on) return;
		var tag = String(d.beta_latest || '').replace(/^v/i, '');
		this.updSet('h5fan-upd-beta-tag', tag || '—');
		var ib = document.getElementById('h5fan-upd-install-beta');
		if (!d.beta_latest) {
			this.updSet('h5fan-upd-beta-status', _('No beta releases found'));
			if (ib) ib.style.display = 'none';
		} else if (d.beta_available == 1 || d.beta_available === true) {
			this.updSet('h5fan-upd-beta-status', '');
			if (ib) ib.style.display = '';
		} else {
			this.updSet('h5fan-upd-beta-status', _('You have the latest beta'));
			if (ib) ib.style.display = 'none';
		}
	},

	onBetaToggle: function(ev) {
		var box = ev && ev.target ? ev.target : document.getElementById('h5fan-upd-beta');
		this.updateBeta({}, !!(box && box.checked));
		if (box && box.checked)
			return this.checkUpdate();
	},

	/* Installation runs in the background; poll the RESULT FILE, not the script
	   (the script binary is replaced during the update). */
	pollInstall: function(tries) {
		tries = tries || 0;
		if (tries > 75) {   // ~5 minutes
			this.updSet('h5fan-upd-status', _('Update is taking too long. Check the connection and try again.'));
			this.updBusy(false);
			return;
		}
		L.resolveDefault(fs.read_direct('/tmp/h5000m_fancontrol_update.json'), '').then(L.bind(function(txt) {
			txt = String(txt || '').trim();
			if (!txt) { this.pollInstall(tries + 1); return; }
			var d = {}; try { d = JSON.parse(txt); } catch (e) { this.pollInstall(tries + 1); return; }
			if (d.running) { this.pollInstall(tries + 1); return; }
			if (d.success) {
				this.updSet('h5fan-upd-current', d.current || '—');
				this.updShow('h5fan-upd-install', false);
				this.updSet('h5fan-upd-status', _('Update installed. Refreshing…'));
				this.finishUpdate();
			} else {
				this.updSet('h5fan-upd-status', this.updErrText(d.error, _('Failed to install the update')));
			}
			this.updBusy(false);
		}, this));
	},

	finishUpdate: function() {
		/* Force the browser to re-fetch the changed view resources, then
		   sign out so the fresh session picks up the new ACL grants. */
		return L.resolveDefault(fetch(L.resource('view/h5000m/fancontrol.js'), { cache: 'reload', credentials: 'same-origin' }), null)
			.catch(function() {}).then(L.bind(function() {
			window.setTimeout(function() {
				var u = L.url('admin/logout');
				if (!u) { window.location.reload(); return; }
				if (L.env && L.env.token) u += '?token=' + encodeURIComponent(L.env.token);
				window.location.href = u;
			}, 1200);
		}, this));
	},

	installUpdate: function(stage) {
		stage = stage || 'stable';
		if (stage === 'beta') {
			if (!confirm(_('Download and install the latest beta version now?'))) return Promise.resolve();
		} else if (stage === 'current') {
			if (!confirm(_('Download and reinstall the currently installed version now?'))) return Promise.resolve();
		} else if (!confirm(_('Download and install the latest version now?'))) {
			return Promise.resolve();
		}
		this.updSet('h5fan-upd-status', _('Installing the update…'));
		this.updBusy(true);
		var self = this;
		/* The RPC response may be lost while the script keeps running in the
		   background (rpcd can hold the request until its timeout); on error
		   read the result file: install may still be running or already done. */
		var fallback = function(errText) {
			return L.resolveDefault(fs.read_direct('/tmp/h5000m_fancontrol_update.json'), '').then(function(txt) {
				var st = {}; try { st = JSON.parse(String(txt || '').trim() || '{}'); } catch (e) {}
				if (st.running || st.success != null) { self.pollInstall(0); return; }
				self.updSet('h5fan-upd-status', errText);
				self.updBusy(false);
			});
		};
		var args = [ 'install' ];
		if (stage === 'beta') args.push('beta');
		if (stage === 'current') args.push('current');
		return fs.exec(UPDATE_BIN, args).then(function(res) {
			var d = {}; try { d = JSON.parse((res && res.stdout) || '{}'); } catch (e) {}
			if (d.started) { self.pollInstall(0); return; }
			if (d.error) {
				self.updSet('h5fan-upd-status', self.updErrText(d.error, _('Failed to install the update')));
				self.updBusy(false);
				return;
			}
			return fallback(_('Failed to install the update'));
		}).catch(function(err) {
			return fallback(_('Failed to install the update') + ' ' + (err.message || err));
		});
	},

	renderUpdateWidget: function(sectionId, optionIndex, cfgvalue) {
		var view = this;
		return E('div', { 'class': 'h5fan-update' }, [
			E('div', { 'class': 'h5fan-update-buttons' }, [
				E('button', { 'class': 'cbi-button cbi-button-action', 'id': 'h5fan-upd-check',
					'click': ui.createHandlerFn(view, function() { return view.checkUpdate(); }) },
					_('Check for updates')),
				E('button', { 'class': 'cbi-button cbi-button-positive', 'id': 'h5fan-upd-install',
					'style': 'display:none',
					'click': ui.createHandlerFn(view, function() { return view.installUpdate(); }) },
					_('Install update')),
				E('button', { 'class': 'cbi-button cbi-button-neutral', 'id': 'h5fan-upd-reinstall',
					'click': ui.createHandlerFn(view, function() { return view.installUpdate('current'); }) },
					_('Reinstall current version')),
				E('a', { 'class': 'cbi-button', 'id': 'h5fan-upd-release',
					'href': UPDATE_RELEASE_URL, 'target': '_blank', 'rel': 'noopener',
					'style': 'display:none' },
					_('Release page'))
			]),
			E('div', { 'class': 'h5fan-update-meta' }, [
				E('div', {}, [ _('Current version') + ': ', E('strong', { 'id': 'h5fan-upd-current' }, '—') ]),
				E('div', { 'id': 'h5fan-upd-status', 'style': 'margin-top:4px' }, '')
			]),
			E('div', { 'class': 'h5fan-update-beta' }, [
				E('label', { 'class': 'h5fan-update-checkbox' }, [
					E('input', { 'type': 'checkbox', 'id': 'h5fan-upd-beta',
						'change': ui.createHandlerFn(view, function(ev) { return view.onBetaToggle(ev); }) }),
					_('Offer beta releases')
				]),
				E('div', { 'class': 'h5fan-update-warn', 'id': 'h5fan-upd-beta-warn', 'style': 'display:none' },
					_('Beta versions may be unstable and are provided for testing. They are not recommended for daily use.')),
				E('div', { 'class': 'h5fan-update-meta', 'id': 'h5fan-upd-beta-wrap', 'style': 'display:none' }, [
					E('div', {}, [ _('Beta') + ': ', E('strong', { 'id': 'h5fan-upd-beta-tag' }, '—') ]),
					E('div', { 'style': 'margin-top:6px' }, [
						E('button', { 'class': 'cbi-button cbi-button-positive', 'id': 'h5fan-upd-install-beta',
							'style': 'display:none',
							'click': ui.createHandlerFn(view, function() { return view.installUpdate('beta'); }) },
							_('Install beta')),
						E('span', { 'style': 'margin-left:8px', 'id': 'h5fan-upd-beta-status' }, '')
					])
				])
			])
		]);
	},

	renderManualPwmWidget: function(option) {
		option.renderWidget = function(sectionId, optionIndex, cfgvalue) {
			var value = cfgvalue || this.default || '160', id = this.cbid(sectionId), rangeId = id + '-range', numberId = id + '-number';
			function sync(value, source) {
				var range = document.getElementById(rangeId), number = document.getElementById(numberId), hidden = document.getElementById(id);
				value = Math.max(0, Math.min(255, parseInt(value, 10) || 0));
				if (range && source !== range) range.value = value;
				if (number && source !== number) number.value = value;
				if (hidden) hidden.value = value;
			}
			return E('div', { 'class': 'h5fan-slider' }, [
				E('input', { id: rangeId, type: 'range', min: 0, max: 255, step: 1, value: value, input: function(ev) { sync(ev.target.value, ev.target); } }),
				E('input', { id: numberId, type: 'number', min: 0, max: 255, step: 1, value: value, input: function(ev) { sync(ev.target.value, ev.target); } }),
				E('input', { id: id, name: id, type: 'hidden', value: value })
			]);
		};
		option.formvalue = function(sectionId) {
			var elem = document.getElementById(this.cbid(sectionId));
			return elem ? elem.value : null;
		};
	},

	renderForm: function() {
		var m = new form.Map('h5000m_fancontrol', _('Cooling policy'));
		var s = m.section(form.NamedSection, 'settings', 'settings'), o;
		m.description = _('Choose a cooling profile or set a manual output. Safety limits remain active in every mode.');
		s.anonymous = true;
		s.tab('policy', _('Policy'));
		s.tab('safety', _('Response & safety'));
		s.tab('update', _('Update'));

		o = s.taboption('policy', form.Flag, 'enabled', _('Enable enhanced controller'));
		o.default = '1'; o.rmempty = false;
		o.description = _('When disabled, the fan follows the kernel thermal protection level only.');

		o = s.taboption('policy', form.ListValue, 'mode', _('Operating mode'));
		o.value('auto', _('Automatic')); o.value('manual', _('Manual')); o.value('kernel', _('Kernel protection only'));
		o.default = 'auto'; o.rmempty = false; o.depends('enabled', '1');

		o = s.taboption('policy', form.ListValue, 'curve', _('Cooling profile'));
		o.value('silent', _('Quiet')); o.value('balanced', _('Balanced')); o.value('performance', _('Performance')); o.value('custom', _('Custom'));
		o.default = 'balanced'; o.rmempty = false; o.depends({ enabled: '1', mode: 'auto' });

		o = s.taboption('policy', form.Value, 'curve_custom', _('Custom curve'));
		o.default = '20:0,40:50,55:60,70:75,85:90,95:100'; o.rmempty = false; o.depends({ enabled: '1', mode: 'auto', curve: 'custom' });
		o.description = _('Comma-separated temperature:percent points. The controller interpolates between points.');
		o.validate = L.bind(this.validateCurve, this);

		o = s.taboption('policy', form.ListValue, 'temp_source', _('Control temperature'));
		o.value('max', _('Hottest available sensor')); o.value('cpu', _('CPU only')); o.default = 'max'; o.rmempty = false; o.depends({ enabled: '1', mode: 'auto' });
		o.description = _('The hottest-sensor option considers CPU, Ethernet PHY, Wi-Fi and the available 5G modem cache.');

		o = s.taboption('policy', form.Value, 'manual_pwm', _('Manual PWM output'));
		o.datatype = 'range(0,255)'; o.default = '160'; o.rmempty = false; o.depends({ enabled: '1', mode: 'manual' });
		o.description = _('The kernel safety floor may raise the effective output above this value.');
		this.renderManualPwmWidget(o);

		o = s.taboption('safety', form.Value, 'interval', _('Control interval'));
		o.datatype = 'range(2,60)'; o.default = '5'; o.rmempty = false; o.description = _('Seconds between control decisions. The dashboard refreshes independently.');

		o = s.taboption('safety', form.Value, 'hysteresis', _('Temperature hysteresis'));
		o.datatype = 'range(0,10)'; o.default = '2'; o.rmempty = false; o.description = _('Prevents repeated speed changes around a curve point.');

		o = s.taboption('safety', form.Value, 'down_delay', _('Speed-down delay'));
		o.datatype = 'range(0,300)'; o.default = '30'; o.rmempty = false; o.description = _('Wait this many seconds before lowering fan output; temperature increases are applied immediately.');

		o = s.taboption('safety', form.Value, 'start_pwm', _('Startup boost PWM'));
		o.datatype = 'range(80,255)'; o.default = '192'; o.rmempty = false;

		o = s.taboption('safety', form.Value, 'start_boost_ms', _('Startup boost duration'));
		o.datatype = 'range(0,3000)'; o.default = '700'; o.rmempty = false; o.description = _('A short boost helps a stopped fan start reliably. Set 0 to disable.');

		o = s.taboption('safety', form.Flag, 'override_floor', _('Ignore firmware fan map'));
		o.default = '0'; o.rmempty = false;
		o.description = _('Advanced. Lets automatic and manual output run below the levels the stock firmware enforces at 40, 85 and 115 °C. The kernel still raises the fan when those trip points are crossed; install patched firmware for full control.');

		o = s.taboption('update', form.DummyValue, '_update', _('Application update'));
		o.anonymous = true; o.rmempty = true;
		o.renderWidget = L.bind(this.renderUpdateWidget, this);

	m.handleSaveApply = function(ev, mode) {
		return form.Map.prototype.handleSaveApply.apply(this, [ ev, mode ]).then(function() {
			return fs.exec('/etc/init.d/h5000m-fancontrol', [ 'restart' ]);
		}).then(function() {
			ui.addNotification(null, E('p', _('Cooling policy applied successfully.')));
		}, function(err) {
			ui.addNotification(null, E('p', _('Failed to apply cooling policy:') + ' ' + err.message), 'danger');
		});
	};
		return m;
	},

	render: function(data) {
		var formMap = this.renderForm();
		return formMap.render().then(L.bind(function(formNode) {
			var root = E('div', { 'class': 'h5fan' }, [ this.styleNode(), this.statusPanel(), this.curvePanel(), formNode ]);
			window.setTimeout(L.bind(function() {
				var wrap = document.getElementById('h5fan-canvas-wrap');
				if (wrap && window.ResizeObserver)
					new ResizeObserver(L.bind(function() { this.chartDraw(); }, this)).observe(wrap);
				window.addEventListener('resize', L.bind(function() { this.chartDraw(); }, this));
				this.updateStatus(data);
				this.fetchVersion();
			}, this), 0);
			poll.add(L.bind(function() {
				return this.fetchStatus().then(L.bind(function(next) { this.updateStatus(next); }, this));
			}, this), 3);
			return root;
		}, this));
	}
});
