// Zion Mainframe — Business Intelligence Data
// This file is loaded by cockpit.js behind auth.
// Keep sensitive strategy data OUT of public repos.

export const SCHEDULE = {
  0: { hat: 'REST', color: '#ffffff', label: 'Rest', times: 'All Day', tasks: ['Recharge'] },
  1: { hat: 'OPERATOR', color: '#ffcc00', label: 'Business', times: 'PM', tasks: ['Analytics', 'Admin'] },
  2: { hat: 'MARKETER', color: '#4488ff', label: 'Content', times: 'PM', tasks: ['Content creation', 'Community'] },
  3: { hat: 'BUILDER', color: '#00ff41', label: 'Deep Work', times: 'PM', tasks: ['Feature dev', 'Bug fixes'] },
  4: { hat: 'MARKETER', color: '#4488ff', label: 'Ship & Share', times: 'PM', tasks: ['Post updates', 'Engage'] },
  5: { hat: 'BUILDER', color: '#00ff41', label: 'Ship Day', times: 'PM', tasks: ['Release', 'Test'] },
  6: { hat: 'RESEARCHER', color: '#00cccc', label: 'Research', times: 'PM', tasks: ['Market research', 'Features'] },
};

export const SPRINT = { name: 'Current Sprint', start: '', end: '', days: [] };
export const TARGETS = [];
export const TASKS = { now: [], week: [], month: [] };
export const SECURITY = [];
export const INTEL = { tam: {}, reachable: {}, goal: '', agents: [] };
export const UNLOCKS = [];

const MONTHS = Array.from({ length: 24 }, (_, i) => `M${i + 1}`);
export { MONTHS };

export function buildPath() { return { profit: [], revenue: [], sales: [], pocket: [], rows: [] }; }
export const GROWTH = { organic: buildPath(), steady: buildPath(), aggressive: buildPath() };
export function quarterAgg() { return { rev: 0, mktg: 0, biz: 0, pocket: 0, hosting: 0 }; }
