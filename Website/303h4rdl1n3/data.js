// Zion Mainframe — Static Business Intelligence
// Edit this file to update schedule, tasks, targets, growth models.
// No build step. ES module consumed by cockpit.js.

// ── Weekly Hat Rotation ──
export const SCHEDULE = {
  0: { hat: 'HUMAN', color: '#ffffff', label: 'Sacred Rest', times: 'All Day', tasks: ['No code', 'Karaoke', 'Family', 'Recharge'] },
  1: { hat: 'OPERATOR', color: '#ffcc00', label: 'Business Admin', times: '3-5pm', tasks: ['Dashboard analytics', 'Bookkeeping (Wave)', 'GitHub issues', 'LLC/legal'] },
  2: { hat: 'MARKETER', color: '#4488ff', label: 'Content Creation', times: '3-5pm', tasks: ['Write/schedule tweets', 'Reddit/blog content', 'Community engagement'] },
  3: { hat: 'BUILDER', color: '#00ff41', label: 'Deep Work (Primary)', times: '3-10pm', tasks: ['Bug fixes', 'Feature dev', 'AI agents in parallel', 'Git commit + push'] },
  4: { hat: 'MARKETER', color: '#4488ff', label: 'Ship & Share', times: '3-5pm', tasks: ['Post what you built', 'Screenshots/progress', 'Respond to engagement'] },
  5: { hat: 'BUILDER', color: '#00ff41', label: 'Ship Day', times: '3-9pm', tasks: ['Finish week\'s feature', 'E2E test', 'Publish release', 'Update roadmap'] },
  6: { hat: 'RESEARCHER', color: '#00cccc', label: 'Big Picture + Build', times: '12-6pm', tasks: ['Competitor check', 'Market research', 'Larger features'] },
};

// ── Current Sprint ──
// Update the focus text here with ACTUAL plans for each day.
// The calendar also pulls real tasks from TASKS below based on hat->department mapping.
export const SPRINT = {
  name: 'Launch Prep + Ghostty Port',
  start: '2026-02-19',
  end: '2026-03-05',
  days: [
    { date: '2026-02-19', dow: 'Wed', hat: 'BUILDER', focus: 'Zion Mainframe cockpit polish. Build v1.0.1 release with UpdateChecker.' },
    { date: '2026-02-20', dow: 'Thu', hat: 'MARKETER', focus: 'Write first Agent Smith email campaign. Screenshot new features for posts.' },
    { date: '2026-02-21', dow: 'Fri', hat: 'BUILDER', focus: 'Rate limiting + CORS security fixes. E2E Round 2 in Sandbox.' },
    { date: '2026-02-22', dow: 'Sat', hat: 'RESEARCHER', focus: 'Ghostty shader port — translate HLSL to GLSL. Test hot-reload.' },
    { date: '2026-02-23', dow: 'Sun', hat: 'HUMAN', focus: 'Karaoke. Recharge.' },
    { date: '2026-02-24', dow: 'Mon', hat: 'OPERATOR', focus: 'Traveling Mailbox setup. LemonSqueezy email config. LLC filing ($104).' },
    { date: '2026-02-25', dow: 'Tue', hat: 'MARKETER', focus: 'Reddit launch post draft (r/commandline). GitHub README redesign.' },
    { date: '2026-02-26', dow: 'Wed', hat: 'BUILDER', focus: 'Ghostty shader polish. FAQ page. BetterStack monitoring setup.' },
    { date: '2026-02-27', dow: 'Thu', hat: 'MARKETER', focus: 'Record 60s demo video. Post Ghostty shader preview to Twitter/X.' },
    { date: '2026-02-28', dow: 'Fri', hat: 'BUILDER', focus: 'Ship day. /dejavu v1.0.1 release. Verify support links. Update README.' },
    { date: '2026-03-01', dow: 'Sat', hat: 'BUILDER', focus: 'Wave bookkeeping setup. Sentry error tracking. Redis backup schedule.' },
    { date: '2026-03-02', dow: 'Sun', hat: 'HUMAN', focus: 'Rest.' },
    { date: '2026-03-03', dow: 'Mon', hat: 'OPERATOR', focus: 'Sprint retrospective. Open business bank account. Plan next sprint.' },
    { date: '2026-03-04', dow: 'Tue', hat: 'MARKETER', focus: 'Product Hunt launch prep. Hacker News "Show HN" draft.' },
    { date: '2026-03-05', dow: 'Wed', hat: 'BUILDER', focus: 'Sprint buffer. VS Code extension research spike.' },
  ],
};

// ── Attack Surface Targets ──
export const TARGETS = [
  { name: 'Windows Terminal', lang: 'HLSL', status: 'SHIPPING', effort: 'Done', reach: '10M+ users', tier: 1 },
  { name: 'OBS Studio', lang: 'HLSL', status: 'READY', effort: 'Hours', reach: '230K+ plugin DLs', tier: 1 },
  { name: 'Shadertoy', lang: 'GLSL', status: 'READY', effort: 'Hours', reach: 'Global community', tier: 1 },
  { name: 'Lively Wallpaper', lang: 'GLSL', status: 'FREE', effort: 'Zero', reach: '18K+ stars', tier: 1 },
  { name: 'Ghostty', lang: 'GLSL', status: 'READY', effort: '1-2 days', reach: '44K stars', tier: 2 },
  { name: 'Windows Screensaver', lang: 'HLSL', status: 'PLANNED', effort: '1-2 days', reach: 'All Windows PCs', tier: 2 },
  { name: 'Wallpaper Engine', lang: 'GLSL', status: 'PLANNED', effort: '1-3 days', reach: '80K+ concurrent', tier: 2 },
  { name: 'VS Code Extension', lang: 'WebGL', status: 'PLANNED', effort: '1-2 weeks', reach: '50M+ users', tier: 2 },
  { name: 'Browser Extension', lang: 'WebGL', status: 'PLANNED', effort: '3-5 days', reach: '3B+ browsers', tier: 3 },
  { name: 'KDE Plasma', lang: 'GLSL', status: 'PLANNED', effort: '1-2 days', reach: 'Linux desktop', tier: 3 },
  { name: 'GNOME ShaderPaper', lang: 'GLSL', status: 'PLANNED', effort: '1-2 days', reach: 'Ubuntu/Fedora', tier: 3 },
  { name: 'Desktop Overlay', lang: 'WebGL', status: 'PLANNED', effort: '1-2 weeks', reach: 'Cross-platform', tier: 3 },
];

// ── Task Board ──
export const TASKS = {
  now: [
    { id: 'NOW-01', dept: 'BIZ', task: 'Get virtual mailing address (Traveling Mailbox Miami)', status: 'in_progress' },
    { id: 'NOW-02', dept: 'BIZ', task: 'Set up LemonSqueezy email sender (requires address)', status: 'pending' },
    { id: 'NOW-05', dept: 'SUP', task: 'Verify support links work (GitHub Issues + email)', status: 'pending' },
    { id: 'NOW-06', dept: 'PLT', task: 'Set up BetterStack free monitoring on API endpoints', status: 'pending' },
    { id: 'NOW-07', dept: 'ENG', task: 'Build v1.0.1 release with UpdateChecker included', status: 'pending' },
  ],
  week: [
    { id: 'WK1-01', dept: 'BIZ', task: 'Form Wyoming LLC ($104 filing)', status: 'pending' },
    { id: 'WK1-02', dept: 'BIZ', task: 'Set up Wave bookkeeping (free)', status: 'pending' },
    { id: 'WK1-03', dept: 'GTM', task: 'Redesign GitHub README — hero GIF, sell Red Pill', status: 'pending' },
    { id: 'WK1-04', dept: 'GTM', task: 'Write launch post for Reddit (r/commandline, r/unixporn)', status: 'pending' },
    { id: 'WK1-05', dept: 'GTM', task: 'Record 60-second demo video for website', status: 'pending' },
    { id: 'WK1-06', dept: 'PLT', task: 'Set up Sentry free tier for API error tracking', status: 'pending' },
    { id: 'WK1-07', dept: 'SUP', task: 'Create FAQ page on website', status: 'pending' },
    { id: 'WK1-09', dept: 'PLT', task: 'Set up Redis backup/export schedule', status: 'pending' },
    { id: 'WK1-10', dept: 'GTM', task: 'Write first Agent Smith email campaign', status: 'pending' },
  ],
  month: [
    { id: 'MO1-01', dept: 'BIZ', task: 'Open business bank account (Mercury/Relay)', status: 'pending' },
    { id: 'MO1-03', dept: 'GTM', task: 'Product Hunt launch', status: 'pending' },
    { id: 'MO1-04', dept: 'GTM', task: 'Hacker News "Show HN" post', status: 'pending' },
    { id: 'MO1-05', dept: 'ENG', task: '"Wake up, [Name]" personalization feature', status: 'pending' },
    { id: 'MO1-06', dept: 'ENG', task: 'E2E Round 2 testing in Windows Sandbox', status: 'pending' },
    { id: 'MO1-07', dept: 'PLT', task: 'Repo split (Website to matrixshader.com)', status: 'pending' },
    { id: 'MO1-08', dept: 'SUP', task: 'Set up Discord server for community + support', status: 'pending' },
    { id: 'MO1-09', dept: 'GTM', task: 'SEO optimization pass on website', status: 'pending' },
    { id: 'MO1-12', dept: 'BIZ', task: 'Quarterly estimated tax planning', status: 'pending' },
    { id: 'MO1-13', dept: 'CEO', task: 'First quarterly cost/optimization audit', status: 'pending' },
    { id: 'MO1-14', dept: 'GTM', task: 'Marketing strategy document', status: 'pending' },
  ],
};

// ── Security Status ──
export const SECURITY = [
  { id: 'SEC-01', task: 'Add rate limiting to /api/subscribe and /api/track', status: 'pending', detail: '@upstash/ratelimit — prevents bot spam' },
  { id: 'SEC-02', task: 'Lock CORS on /api/subscribe and /api/validate', status: 'pending', detail: 'Currently Access-Control-Allow-Origin: * — lock to matrixshader.com' },
  { id: 'SEC-03', task: 'Add unsubscribe endpoint (/api/unsubscribe)', status: 'pending', detail: 'Required by CAN-SPAM. Add unsubscribe link to emails' },
  { id: 'SEC-04', task: 'Use timing-safe comparison for dashboard password', status: 'done', detail: 'crypto.timingSafeEqual + TOTP 2FA implemented' },
  { id: 'SEC-05', task: 'Add photosensitivity/seizure warning', status: 'pending', detail: 'README, installer, and website health note' },
  { id: 'SEC-06', task: 'GDPR compliance — data deletion capability', status: 'pending', detail: 'Users can request email deletion via /api/unsubscribe' },
];

// ── Market Intelligence ──
export const INTEL = {
  tam: { before: '$475M', after: '$1.5B', label: 'Total Addressable Market' },
  reachable: { before: '$40M', after: '$95M', label: 'Reachable Market' },
  goal: '$400K',
  goalPercent: '0.42%',
  salesNeeded: '47,100',
  competition: 'ZERO direct competitors',
  comparable: 'Wallpaper Engine: $155M revenue, 20-50M copies sold',
  costPerMonth: '$21',
  netPerSale: { founders: '$4.25', full: '$9.00' },
  agents: [
    { target: 'Ghostty', finding: 'GLSL Shadertoy-compatible, 44K stars, hot-reload, macOS+Linux vibe coders', confidence: 'HIGH' },
    { target: 'Kitty', finding: 'Maintainer rejected shaders. Fork possible (GPLv3). AI agent auto-rebase.', confidence: 'HIGH' },
    { target: 'OBS Studio', finding: 'HLSL works as-is via obs-shaderfilter. 230K+ downloads. Streamers = billboards.', confidence: 'HIGH' },
    { target: 'VS Code', finding: '50M+ users, WebGL2 injection, zero competition for GPU terminal backgrounds.', confidence: 'MEDIUM' },
    { target: 'Wallpaper Engine', finding: '20-50M Steam owners, free Workshop listing = marketing funnel.', confidence: 'MEDIUM' },
    { target: 'Lively Wallpaper', finding: '18K stars, loads Shadertoy URLs directly. Zero effort once GLSL exists.', confidence: 'HIGH' },
    { target: 'Shadertoy', finding: 'Gateway to 4+ platforms. One publish = Lively + KDE + GNOME + embeds.', confidence: 'HIGH' },
    { target: 'Windows Screensaver', finding: 'Rename .exe to .scr. C#/.NET already exists. All Windows PCs.', confidence: 'HIGH' },
    { target: 'KDE Plasma', finding: 'kde-shader-wallpaper plugin, Shadertoy-compatible. Low effort.', confidence: 'MEDIUM' },
    { target: 'GNOME ShaderPaper', finding: 'Ubuntu/Fedora default desktop. Shadertoy-compatible extension.', confidence: 'MEDIUM' },
    { target: 'Browser Extension', finding: 'WebGL new-tab page. Chrome 3B+ users. VibeTab is prior art.', confidence: 'MEDIUM' },
    { target: 'Termux Fork', finding: 'GPLv3. GLSurfaceView + transparent Canvas. 10-14wk MVP. Mobile terminal.', confidence: 'MEDIUM' },
  ],
};

// ── "What Unlocks Each Level" Table ──
export const UNLOCKS = [
  { action: 'Steam listing', cost: '$100', costClass: 'red', expected: '5K-50K/yr', expectedClass: 'green' },
  { action: 'Microsoft Store', cost: '$0', costClass: 'dim', expected: '2K-20K/yr', expectedClass: 'green' },
  { action: 'Product Hunt', cost: '$0', costClass: 'dim', expected: '250-4K', expectedClass: 'green' },
  { action: 'Hacker News', cost: '$0', costClass: 'dim', expected: '100-1.5K', expectedClass: 'green' },
  { action: 'Reddit posts', cost: '$0', costClass: 'dim', expected: '20-1.5K each', expectedClass: 'green' },
  { action: '1 micro-creator', cost: '$0-300', costClass: 'red', expected: '50-600', expectedClass: 'green' },
  { action: '1 mid YouTuber', cost: '$500-2K', costClass: 'red', expected: '500-4K', expectedClass: 'green' },
  { action: 'Web demo', cost: '$0 (time)', costClass: 'dim', expected: '2-3x conv. rate', expectedClass: 'gold' },
  { action: 'Theme packs', cost: '$0 (time)', costClass: 'dim', expected: '+$3-7/buyer', expectedClass: 'gold' },
  { action: 'Google Ads', cost: '$1-3/click', costClass: 'red', expected: '2-5% conv.', expectedClass: 'green' },
  { action: 'GLSL port (1-2 days)', cost: '$0 (time)', costClass: 'dim', expected: 'Unlocks 8+ platforms', expectedClass: 'gold', highlight: true },
  { action: 'Ghostty shader', cost: '$0 (time)', costClass: 'dim', expected: '1K-10K/yr', expectedClass: 'green' },
  { action: 'VS Code extension', cost: '$0 (time)', costClass: 'dim', expected: '5K-100K/yr', expectedClass: 'green' },
  { action: 'OBS shaderfilter', cost: '$0 (time)', costClass: 'dim', expected: 'Streamer billboards', expectedClass: 'gold' },
  { action: 'Shadertoy publish', cost: '$0', costClass: 'dim', expected: 'Gateway to 4 platforms', expectedClass: 'gold' },
  { action: 'Wallpaper Engine', cost: '$0', costClass: 'dim', expected: 'Funnel: 20-50M users', expectedClass: 'green' },
  { action: 'Win screensaver', cost: '$0 (time)', costClass: 'dim', expected: '2K-20K/yr', expectedClass: 'green' },
  { action: 'Browser extension', cost: '$0 (time)', costClass: 'dim', expected: '1K-10K/yr', expectedClass: 'green' },
];

// ── Growth Model (ported from valuation-spread.html) ──
const MONTHS = Array.from({ length: 24 }, (_, i) => `M${i + 1}`);
export { MONTHS };

function organicGrowth(m) {
  // Viral IS organic. A visual product with zero competition gets shared naturally.
  // Includes: Show HN, Reddit posts, Twitter/X virality, YouTube demos, word of mouth.
  // Every viral moment converts at high rates because there's nothing else like it.
  if (m <= 1) return 2;       // Launch buzz — Show HN, first tweets, friends
  if (m <= 2) return 5;       // Community picks it up, Reddit r/commandline
  if (m <= 3) return 10;      // First viral moment — visual products get shared
  if (m <= 5) return 10 + (m - 3) * 6;   // 16, 22 — multi-platform presence
  if (m <= 8) return 22 + (m - 5) * 6;   // 28, 34, 40 — word of mouth flywheel
  if (m <= 12) return 40 + (m - 8) * 7;  // 47, 54, 61, 68 — category awareness
  if (m <= 18) return 68 + (m - 12) * 5; // 73-98 — sustained organic + viral bursts
  return Math.min(120, 98 + (m - 18) * 4); // 102-120 — mature organic ceiling
}

function steadyGrowth(m, cumMktg) {
  const mktgBoost = 1 + (cumMktg / 5000) * 0.3;
  let base;
  if (m <= 1) return 2;
  if (m <= 2) base = 5;
  else if (m <= 3) base = 5 + (m - 2) * 5;
  else if (m <= 5) base = 10 + (m - 3) * 6;
  else if (m <= 7) base = 22 + (m - 5) * 8;
  else if (m <= 9) base = 38 + (m - 7) * 6;
  else if (m <= 12) base = 50 + (m - 9) * 5;
  else if (m <= 18) base = 65 + (m - 12) * 3;
  else base = 83 + (m - 18) * 2;
  return base * Math.min(mktgBoost, 2.5);
}

function aggressiveGrowth(m, cumMktg) {
  const mktgBoost = 1 + (cumMktg / 3000) * 0.4;
  let base;
  if (m <= 1) return 5;
  if (m <= 2) base = 15;
  else if (m <= 3) base = 30;
  else if (m <= 5) base = 35 + (m - 3) * 20;
  else if (m <= 7) base = 75 + (m - 5) * 25;
  else if (m <= 9) base = 125 + (m - 7) * 20;
  else if (m <= 12) base = 165 + (m - 9) * 15;
  else if (m <= 18) base = 210 + (m - 12) * 10;
  else base = 270 + (m - 18) * 6;
  return base * Math.min(mktgBoost, 3.0);
}

export function buildPath(name, growthFn) {
  let cumSales = 0, cumRevenue = 0, cumProfit = 0, cumPocket = 0, cumMarketing = 0;
  const data = { profit: [], revenue: [], sales: [], pocket: [], rows: [] };
  const reinvestRate = name === 'organic' ? 0 : name === 'steady' ? 0.5 : 0.7;
  const businessCosts = [0, 0, 200, 350, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  for (let m = 0; m < 24; m++) {
    const dailySales = growthFn(m + 1, cumMarketing);
    const monthlySales = Math.round(dailySales * 30);
    const remainFounder = Math.max(0, 5000 - cumSales);
    let netRev;
    if (remainFounder >= monthlySales) {
      netRev = monthlySales * 4.25;
    } else if (remainFounder > 0) {
      netRev = remainFounder * 4.25 + (monthlySales - remainFounder) * 9.00;
    } else {
      netRev = monthlySales * 9.00;
    }
    const addon = m >= 4 ? monthlySales * 0.18 * 2.00 : 0;
    const grossProfit = netRev + addon - 21.25;
    const bizCost = businessCosts[m] || 0;
    const marketing = Math.max(0, (grossProfit - bizCost) * reinvestRate);
    const pocket = grossProfit - bizCost - marketing;

    cumSales += monthlySales;
    cumRevenue += netRev + addon;
    cumProfit += grossProfit;
    cumPocket += pocket;
    cumMarketing += marketing;

    data.profit.push(Math.round(cumProfit));
    data.revenue.push(Math.round(netRev + addon));
    data.sales.push(Math.round(dailySales * 10) / 10);
    data.pocket.push(Math.round(cumPocket));
    data.rows.push({
      month: m + 1, sales: monthlySales, cumSales,
      revenue: Math.round(netRev + addon), pocket: Math.round(pocket),
      cumPocket: Math.round(cumPocket), marketing: Math.round(marketing),
      bizCost: Math.round(bizCost),
    });
  }
  return data;
}

export const GROWTH = {
  organic: buildPath('organic', organicGrowth),
  steady: buildPath('steady', steadyGrowth),
  aggressive: buildPath('aggressive', aggressiveGrowth),
};

// Quarterly aggregation for waterfall chart
export function quarterAgg(rows, startM, endM) {
  let rev = 0, mktg = 0, biz = 0, pocket = 0;
  rows.filter(r => r.month >= startM && r.month <= endM).forEach(r => {
    rev += r.revenue; mktg += r.marketing; biz += r.bizCost; pocket += r.pocket;
  });
  return { rev, mktg, biz, pocket, hosting: (endM - startM + 1) * 21.25 };
}
