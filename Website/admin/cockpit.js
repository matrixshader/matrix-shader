// Zion Mainframe — Main Application
// ES module: auth, API, charts, tabs, renderers.

import {
  SCHEDULE, SPRINT, TARGETS, TASKS, SECURITY,
  INTEL, UNLOCKS, MONTHS, GROWTH, buildPath, quarterAgg,
} from '/admin/data.js';

const API = '/api/dashboard';
let trafficChart = null;
let growthChart = null;
let waterfallChart = null;
let refreshTimer = null;

// ── DOM refs ──
const $ = (id) => document.getElementById(id);
const overlay = $('auth-overlay');
const dashboard = $('dashboard');
const pwInput = $('auth-password');
const authError = $('auth-error');
const videoBg = $('matrix-bg');

// ── Auth ──
function getToken() { return sessionStorage.getItem('zion_token'); }
function setToken(t) { sessionStorage.setItem('zion_token', t); }
function clearToken() { sessionStorage.removeItem('zion_token'); }

async function authenticate(pw) {
  authError.textContent = '';
  try {
    const res = await fetch(API, { headers: { 'Authorization': `Bearer ${pw}` } });
    if (res.status === 401) { authError.textContent = 'Access denied.'; return null; }
    if (!res.ok) { authError.textContent = 'Server error.'; return null; }
    return await res.json();
  } catch {
    authError.textContent = 'Connection failed.';
    return null;
  }
}

function showDashboard(data) {
  overlay.classList.add('hidden');
  dashboard.classList.remove('hidden');
  videoBg.classList.add('visible');
  renderAll(data);
  startAutoRefresh();
}

function logout() {
  clearToken();
  stopAutoRefresh();
  dashboard.classList.add('hidden');
  overlay.classList.remove('hidden');
  videoBg.classList.remove('visible');
  pwInput.value = '';
  authError.textContent = '';
}

async function loadData() {
  const token = getToken();
  if (!token) return;
  try {
    const res = await fetch(API, { headers: { 'Authorization': `Bearer ${token}` } });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) return;
    const data = await res.json();
    renderAll(data);
    updateTimestamp();
  } catch { /* silent fail on refresh */ }
}

function startAutoRefresh() {
  stopAutoRefresh();
  refreshTimer = setInterval(loadData, 60000);
}
function stopAutoRefresh() {
  if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
}

let lastRefresh = Date.now();
function updateTimestamp() {
  lastRefresh = Date.now();
  renderTimestamp();
}
function renderTimestamp() {
  const el = $('last-updated');
  if (!el) return;
  const ago = Math.round((Date.now() - lastRefresh) / 1000);
  if (ago < 5) el.textContent = 'Just now';
  else if (ago < 60) el.textContent = `${ago}s ago`;
  else el.textContent = `${Math.round(ago / 60)}m ago`;
}
setInterval(renderTimestamp, 5000);

// ── Tabs ──
function switchTab(tabId) {
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tabId));
  document.querySelectorAll('.tab-panel').forEach(p => p.classList.toggle('active', p.id === `tab-${tabId}`));
}

// ── Render All ──
function renderAll(data) {
  renderKpiBar(data.totals);
  renderMetrics(data.totals);
  renderFunnel(data.funnel);
  renderChart(data.timeseries);
  renderSubscribers(data.subscribers);
  renderLicenses(data.licenses);
  // Static tabs (render once)
  renderCalendar();
  renderStrategy();
  renderIntel();
  updateTimestamp();
}

// ── KPI Bar ──
function renderKpiBar(t) {
  const items = [
    { label: 'Views', value: t.page_views },
    { label: 'Downloads', value: t.downloads },
    { label: 'Installs', value: t.installs },
    { label: 'Activations', value: t.activations },
    { label: 'Purchases', value: t.purchases },
    { label: 'Subscribers', value: t.subscribers },
  ];
  $('kpi-bar').innerHTML = items.map(m =>
    `<div class="kpi-card">
      <div class="kpi-value">${m.value.toLocaleString()}</div>
      <div class="kpi-label">${m.label}</div>
    </div>`
  ).join('');
}

// ── Analytics: Metrics ──
function renderMetrics(t) {
  const items = [
    { label: 'Page Views', value: t.page_views },
    { label: 'Downloads', value: t.downloads },
    { label: 'Installs', value: t.installs },
    { label: 'Activations', value: t.activations },
    { label: 'Subscribers', value: t.subscribers },
    { label: 'Purchases', value: t.purchases },
    { label: 'Redpill Clicks', value: t.redpill_clicks },
    { label: 'GitHub Clicks', value: t.github_clicks },
  ];
  $('metrics').innerHTML = items.map(m =>
    `<div class="metric">
      <div class="metric-value">${m.value.toLocaleString()}</div>
      <div class="metric-label">${m.label}</div>
    </div>`
  ).join('');
}

// ── Analytics: Funnel ──
function renderFunnel(f) {
  const steps = [
    { label: 'Page Views', count: f.page_views },
    { label: 'Redpill Clicks', count: f.redpill_clicks },
    { label: 'Downloads', count: f.downloads },
    { label: 'Purchases', count: f.purchases },
  ];
  const max = Math.max(...steps.map(s => s.count), 1);
  $('funnel').innerHTML =
    steps.map(s =>
      `<div class="funnel-row">
        <div class="funnel-label">${s.label}</div>
        <div class="funnel-bar-bg">
          <div class="funnel-bar" style="width:${(s.count / max * 100).toFixed(1)}%"></div>
        </div>
        <div class="funnel-count">${s.count.toLocaleString()}</div>
      </div>`
    ).join('') +
    `<div class="funnel-conversion">Conversion: <strong>${f.conversion_rate}</strong></div>`;
}

// ── Analytics: Traffic Chart ──
function renderChart(ts) {
  const ctx = $('traffic-chart').getContext('2d');
  const labels = (ts.page_view || []).map(d => d.date.slice(5));
  if (trafficChart) trafficChart.destroy();
  trafficChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [
        { label: 'Page Views', data: (ts.page_view || []).map(d => d.count), borderColor: '#00ff41', backgroundColor: 'rgba(0,255,65,0.1)', fill: true, tension: 0.3, pointRadius: 2, borderWidth: 2 },
        { label: 'Downloads', data: (ts.download || []).map(d => d.count), borderColor: '#ffcc00', backgroundColor: 'rgba(255,204,0,0.05)', fill: true, tension: 0.3, pointRadius: 2, borderWidth: 2 },
        { label: 'Redpill Clicks', data: (ts.redpill_click || []).map(d => d.count), borderColor: '#ff0040', backgroundColor: 'rgba(255,0,64,0.05)', fill: true, tension: 0.3, pointRadius: 2, borderWidth: 2 },
      ],
    },
    options: chartOptions(),
  });
}

function chartOptions() {
  return {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { intersect: false, mode: 'index' },
    plugins: {
      legend: { labels: { color: '#4a7a4a', font: { family: "'JetBrains Mono'", size: 10 } } },
      tooltip: { backgroundColor: 'rgba(0,10,0,0.9)', borderColor: 'rgba(0,255,65,0.2)', borderWidth: 1, titleFont: { family: "'JetBrains Mono'" }, bodyFont: { family: "'JetBrains Mono'" } },
    },
    scales: {
      x: { ticks: { color: '#4a7a4a', font: { family: "'JetBrains Mono'", size: 10 } }, grid: { color: 'rgba(0,255,65,0.05)' } },
      y: { beginAtZero: true, ticks: { color: '#4a7a4a', font: { family: "'JetBrains Mono'", size: 10 } }, grid: { color: 'rgba(0,255,65,0.05)' } },
    },
  };
}

// ── Analytics: Tables ──
function esc(str) { const d = document.createElement('div'); d.textContent = str; return d.innerHTML; }
function fmtDate(iso) { return iso ? iso.slice(0, 10) : '-'; }

function renderSubscribers(subs) {
  const el = $('subscribers-table');
  if (!subs || !subs.length) { el.innerHTML = '<div class="empty-state">No subscribers yet</div>'; return; }
  el.innerHTML = `<table><thead><tr><th>Email</th><th>Name</th><th>Source</th><th>Date</th></tr></thead>
    <tbody>${subs.map(s => `<tr><td>${esc(s.email)}</td><td>${esc(s.name || '-')}</td><td>${esc(s.source || '-')}</td><td>${fmtDate(s.subscribedAt)}</td></tr>`).join('')}</tbody></table>`;
}

function renderLicenses(lics) {
  const el = $('licenses-table');
  if (!lics || !lics.length) { el.innerHTML = '<div class="empty-state">No licenses yet</div>'; return; }
  el.innerHTML = `<table><thead><tr><th>Order</th><th>Email</th><th>Name</th><th>Activations</th><th>Date</th></tr></thead>
    <tbody>${lics.map(l => `<tr><td>${esc(l.orderId)}</td><td>${esc(l.email || '-')}</td><td>${esc(l.buyerName || '-')}</td><td>${l.activationCount}</td><td>${fmtDate(l.createdAt)}</td></tr>`).join('')}</tbody></table>`;
}

// ── Calendar Tab ──
function renderCalendar() {
  const now = new Date();
  const today = now.getDay(); // 0=Sun
  const todayISO = now.toISOString().slice(0, 10);
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Weekly strip
  let weekHtml = '';
  for (let d = 0; d < 7; d++) {
    const info = SCHEDULE[d];
    const isToday = d === today;
    weekHtml += `<div class="week-day${isToday ? ' today' : ''}">
      <div class="day-label">${dayNames[d]}</div>
      <div class="day-hat" style="color:${info.color}">${info.hat}</div>
      <div class="day-time">${info.times}</div>
    </div>`;
  }
  $('week-strip').innerHTML = weekHtml;

  // Today's focus card
  const todayInfo = SCHEDULE[today];
  $('today-card').innerHTML = `
    <div class="today-header">
      <div class="today-hat" style="color:${todayInfo.color}">${todayInfo.hat}</div>
      <div class="today-time">${todayInfo.times}</div>
    </div>
    <div class="today-label">${todayInfo.label}</div>
    <ul class="today-tasks">
      ${todayInfo.tasks.map(t => `<li>${esc(t)}</li>`).join('')}
    </ul>`;
  $('today-card').style.borderLeftColor = todayInfo.color;

  // Sprint timeline
  $('sprint-name').textContent = `${SPRINT.name} (${SPRINT.start} to ${SPRINT.end})`;
  let sprintHtml = '';
  for (const day of SPRINT.days) {
    const hatInfo = SCHEDULE[new Date(day.date + 'T12:00:00').getDay()];
    const isToday = day.date === todayISO;
    const isPast = day.date < todayISO;
    sprintHtml += `<div class="sprint-day${isToday ? ' today' : ''}${isPast ? ' past' : ''}" title="${esc(day.focus)}">
      <div class="sd-dow">${day.dow}</div>
      <div class="sd-date">${day.date.slice(5)}</div>
      <div class="sd-hat" style="color:${hatInfo.color}">${hatInfo.hat.slice(0, 3)}</div>
    </div>`;
  }
  $('sprint-timeline').innerHTML = sprintHtml;
}

// ── Strategy Tab ──
function renderStrategy() {
  renderGrowthChart();
  renderWaterfallChart();
  renderAttackSurface();
  renderMonthlyTable();
  renderUnlocksTable();
  renderTaskBoard();
  renderSecurityStatus();
}

// Growth chart
const goalLinePlugin = {
  id: 'goalLine',
  afterDraw(chart) {
    if (chart.canvas.id !== 'growth-chart') return;
    const maxVal = Math.max(...chart.data.datasets[0].data);
    if (maxVal < 50000) return;
    const yScale = chart.scales.y;
    if (400000 > yScale.max) return;
    const y = yScale.getPixelForValue(400000);
    const xScale = chart.scales.x;
    const ctx = chart.ctx;
    ctx.save();
    ctx.beginPath();
    ctx.setLineDash([6, 4]);
    ctx.strokeStyle = '#ffd700';
    ctx.globalAlpha = 0.6;
    ctx.lineWidth = 1.5;
    ctx.moveTo(xScale.left, y);
    ctx.lineTo(xScale.right, y);
    ctx.stroke();
    ctx.globalAlpha = 0.8;
    ctx.fillStyle = '#ffd700';
    ctx.font = 'bold 11px JetBrains Mono';
    ctx.fillText('$400K GOAL', xScale.right - 90, y - 8);
    ctx.restore();
  }
};

function makeGrowthDatasets(key) {
  return [
    { label: 'Aggressive', data: GROWTH.aggressive[key], borderColor: '#00ff41', backgroundColor: 'rgba(0,255,65,0.06)', fill: true, tension: 0.3, borderWidth: 2.5, pointRadius: 0, pointHoverRadius: 4 },
    { label: 'Steady', data: GROWTH.steady[key], borderColor: '#ffd700', backgroundColor: 'rgba(255,215,0,0.04)', fill: true, tension: 0.3, borderWidth: 2, pointRadius: 0, pointHoverRadius: 4 },
    { label: 'Organic', data: GROWTH.organic[key], borderColor: '#ff4444', backgroundColor: 'rgba(255,68,68,0.03)', fill: true, tension: 0.3, borderWidth: 1.5, pointRadius: 0, pointHoverRadius: 4 },
  ];
}

function renderGrowthChart() {
  const ctx = $('growth-chart').getContext('2d');
  if (growthChart) growthChart.destroy();
  growthChart = new Chart(ctx, {
    type: 'line',
    data: { labels: MONTHS, datasets: makeGrowthDatasets('profit') },
    options: {
      responsive: true, maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { labels: { usePointStyle: true, padding: 14, font: { size: 10, family: "'JetBrains Mono'" }, color: '#4a7a4a' } },
        tooltip: {
          backgroundColor: 'rgba(0,10,0,0.92)', borderColor: 'rgba(0,255,65,0.3)', borderWidth: 1,
          titleFont: { family: "'JetBrains Mono'" }, bodyFont: { family: "'JetBrains Mono'" },
          callbacks: { label: ctx => { const v = ctx.parsed.y; return v >= 1000 ? `${ctx.dataset.label}: $${(v / 1000).toFixed(1)}K` : `${ctx.dataset.label}: $${v}`; } },
        },
      },
      scales: {
        y: { ticks: { callback: v => v >= 1e6 ? '$' + (v / 1e6).toFixed(1) + 'M' : v >= 1000 ? '$' + (v / 1000).toFixed(0) + 'K' : '$' + v, color: '#4a7a4a', font: { family: "'JetBrains Mono'", size: 10 } }, grid: { color: 'rgba(0,255,65,0.04)' } },
        x: { ticks: { callback: (v, i) => i === 0 ? 'M1' : i === 5 ? 'M6' : i === 11 ? 'Y1' : i === 17 ? 'M18' : i === 23 ? 'Y2' : '', color: '#4a7a4a', font: { family: "'JetBrains Mono'", size: 10 } }, grid: { color: 'rgba(0,255,65,0.03)' } },
      },
    },
    plugins: [goalLinePlugin],
  });

  // Wire up view buttons
  document.querySelectorAll('[data-growth-view]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('[data-growth-view]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const view = btn.dataset.growthView;
      growthChart.data.datasets = makeGrowthDatasets(view);
      if (view === 'sales') {
        growthChart.options.scales.y.ticks.callback = v => v + '/day';
      } else {
        growthChart.options.scales.y.ticks.callback = v => v >= 1e6 ? '$' + (v / 1e6).toFixed(1) + 'M' : v >= 1000 ? '$' + (v / 1000).toFixed(0) + 'K' : '$' + v;
      }
      growthChart.update();
    });
  });
}

// Waterfall chart
function renderWaterfallChart() {
  const rows = GROWTH.aggressive.rows;
  const quarters = [];
  for (let i = 0; i < 8; i++) {
    quarters.push(quarterAgg(rows, i * 3 + 1, i * 3 + 3));
  }
  const qLabels = quarters.map((_, i) => `Q${i + 1}`);

  const ctx = $('waterfall-chart').getContext('2d');
  if (waterfallChart) waterfallChart.destroy();
  waterfallChart = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: qLabels,
      datasets: [
        { label: 'Your Pocket', data: quarters.map(q => Math.round(q.pocket)), backgroundColor: 'rgba(0,255,65,0.5)', borderColor: '#00ff41', borderWidth: 1 },
        { label: 'Marketing', data: quarters.map(q => Math.round(q.mktg)), backgroundColor: 'rgba(255,165,0,0.4)', borderColor: '#ffa500', borderWidth: 1 },
        { label: 'Biz Costs', data: quarters.map(q => Math.round(q.biz + q.hosting)), backgroundColor: 'rgba(255,68,68,0.3)', borderColor: '#ff4444', borderWidth: 1 },
      ],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { labels: { usePointStyle: true, padding: 14, font: { size: 10, family: "'JetBrains Mono'" }, color: '#4a7a4a' } },
        tooltip: {
          backgroundColor: 'rgba(0,10,0,0.92)', borderColor: 'rgba(0,255,65,0.3)', borderWidth: 1,
          titleFont: { family: "'JetBrains Mono'" }, bodyFont: { family: "'JetBrains Mono'" },
          callbacks: { label: ctx => `${ctx.dataset.label}: $${(ctx.parsed.y / 1000).toFixed(1)}K` },
        },
      },
      scales: {
        x: { stacked: true, grid: { color: 'rgba(0,255,65,0.03)' }, ticks: { color: '#4a7a4a', font: { family: "'JetBrains Mono'", size: 10 } } },
        y: { stacked: true, ticks: { callback: v => '$' + (v >= 1000 ? (v / 1000).toFixed(0) + 'K' : v), color: '#4a7a4a', font: { family: "'JetBrains Mono'", size: 10 } }, grid: { color: 'rgba(0,255,65,0.04)' } },
      },
    },
  });
}

// Attack surface
function renderAttackSurface() {
  $('attack-surface').innerHTML = `<ul class="target-list">
    ${TARGETS.map(t => {
      const sc = t.status.toLowerCase().replace(/\s/g, '');
      return `<li class="target-item">
        <span class="target-status ${sc}">${t.status}</span>
        <span class="target-name">${esc(t.name)}</span>
        <span class="target-lang">${t.lang}</span>
        <span class="target-effort">${t.effort}</span>
      </li>`;
    }).join('')}
  </ul>`;
}

// Monthly table (aggressive path)
function renderMonthlyTable() {
  const tbody = $('monthly-table-body');
  tbody.innerHTML = GROWTH.aggressive.rows.map((r, i) => {
    const isGoal = r.cumPocket >= 400000 && (i === 0 || GROWTH.aggressive.rows[i - 1].cumPocket < 400000);
    return `<tr${isGoal ? ' class="highlight"' : ''}>
      <td>${r.month}</td>
      <td>${r.sales.toLocaleString()}</td>
      <td class="green">$${r.revenue.toLocaleString()}</td>
      <td>$${r.pocket.toLocaleString()}</td>
      <td class="${r.cumPocket >= 400000 ? 'gold' : ''}">${r.cumPocket >= 1000 ? '$' + (r.cumPocket / 1000).toFixed(1) + 'K' : '$' + r.cumPocket}</td>
    </tr>`;
  }).join('');
}

// Unlocks table
function renderUnlocksTable() {
  $('unlocks-table-body').innerHTML = UNLOCKS.map(u =>
    `<tr${u.highlight ? ' class="highlight"' : ''}>
      <td${u.highlight ? ' style="color:#ffd700"' : ''}>${esc(u.action)}</td>
      <td class="${u.costClass}">${u.cost}</td>
      <td class="${u.expectedClass}">${u.expected}</td>
    </tr>`
  ).join('');
}

// Task board
function renderTaskBoard() {
  const groups = [
    { key: 'now', title: 'NOW', color: 'var(--red)' },
    { key: 'week', title: 'THIS WEEK', color: 'var(--yellow)' },
    { key: 'month', title: 'THIS MONTH', color: 'var(--green)' },
  ];
  $('task-board').innerHTML = groups.map(g => {
    const tasks = TASKS[g.key];
    return `<div class="task-group">
      <div class="task-group-title" style="color:${g.color}">
        ${g.title} <span class="task-count">${tasks.length}</span>
      </div>
      ${tasks.map(t => `<div class="task-item">
        <span class="task-dept">${t.dept}</span>
        <span>${esc(t.task)}</span>
        <span class="task-badge ${t.status}">${t.status === 'in_progress' ? 'WIP' : 'TODO'}</span>
      </div>`).join('')}
    </div>`;
  }).join('');
}

// Security status
function renderSecurityStatus() {
  $('security-status').innerHTML = SECURITY.map(s =>
    `<div class="sec-item">
      <span class="sec-id">${s.id}</span>
      <span class="sec-text">${esc(s.task)}</span>
      <span class="sec-badge">PENDING</span>
    </div>`
  ).join('');
}

// ── Intel Tab ──
function renderIntel() {
  // Market stats
  $('intel-market').innerHTML = `
    <div class="intel-stat"><div class="is-value">${INTEL.tam.after}</div><div class="is-label">TAM (expanded)</div><div class="is-note">Was ${INTEL.tam.before}</div></div>
    <div class="intel-stat"><div class="is-value">${INTEL.reachable.after}</div><div class="is-label">Reachable Market</div><div class="is-note">Was ${INTEL.reachable.before}</div></div>
    <div class="intel-stat"><div class="is-value gold">${INTEL.goal}</div><div class="is-label">Your Goal</div><div class="is-note">${INTEL.goalPercent} of reachable</div></div>
    <div class="intel-stat"><div class="is-value">${INTEL.salesNeeded}</div><div class="is-label">Sales Needed</div><div class="is-note">5K at $5 + 42.1K at $10</div></div>
    <div class="intel-stat"><div class="is-value">${INTEL.costPerMonth}</div><div class="is-label">Monthly Cost</div><div class="is-note">Hosting + domain</div></div>
    <div class="intel-stat"><div class="is-value">$0</div><div class="is-label">Competition</div><div class="is-note">${INTEL.competition}</div></div>`;

  // Agent findings
  $('agent-findings').innerHTML = `<ul class="agent-list">
    ${INTEL.agents.map(a => `<li class="agent-item">
      <span class="agent-target">${esc(a.target)}</span>
      <span class="agent-finding">${esc(a.finding)}</span>
      <span class="agent-conf ${a.confidence}">${a.confidence}</span>
    </li>`).join('')}
  </ul>`;

  // Comparable
  $('intel-comparable').innerHTML = `
    <div style="padding:12px;background:rgba(255,215,0,0.05);border:1px solid rgba(255,215,0,0.15);border-radius:8px;font-size:12px;color:#aa9944;line-height:1.8">
      <strong style="color:#ffd700">Comparable: Wallpaper Engine</strong><br>
      ${INTEL.comparable}<br>
      MatrixShader is the developer-terminal version of that same idea, now going everywhere.
    </div>`;
}

// ── Video Background ──
function setupVideo() {
  // Try blue video first, fall back to green
  const blueSource = videoBg.querySelector('source[data-blue]');
  const greenSource = videoBg.querySelector('source[data-green]');
  if (blueSource) {
    videoBg.src = '';
    const blueSrc = blueSource.getAttribute('src');
    videoBg.src = blueSrc;
    videoBg.load();
    videoBg.onerror = () => {
      if (greenSource) {
        videoBg.src = greenSource.getAttribute('src');
        videoBg.load();
      }
    };
  }
}

// ── Init ──
function init() {
  // Auth handlers
  $('auth-submit').addEventListener('click', async () => {
    const pw = pwInput.value.trim();
    if (!pw) return;
    const data = await authenticate(pw);
    if (data) {
      setToken(pw);
      setupVideo();
      showDashboard(data);
    }
  });

  pwInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') $('auth-submit').click();
  });

  $('btn-logout').addEventListener('click', logout);
  $('btn-refresh').addEventListener('click', loadData);

  // Tab handlers
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });

  // Auto-login from session
  (async () => {
    const token = getToken();
    if (token) {
      const data = await authenticate(token);
      if (data) {
        setupVideo();
        showDashboard(data);
        return;
      }
      clearToken();
    }
  })();
}

// Chart.js defaults
Chart.defaults.color = '#6a8a6a';
Chart.defaults.borderColor = 'rgba(0,255,65,0.06)';
Chart.defaults.font.family = "'JetBrains Mono', monospace";
Chart.defaults.font.size = 11;

init();
