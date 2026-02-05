#!/usr/bin/env node
const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Check if running on Windows
if (process.platform !== 'win32') {
  console.log('\n  Matrix Shader requires Windows with Windows Terminal.\n');
  process.exit(0);
}

// Check if Windows Terminal is installed
const wtSettingsPath = path.join(
  process.env.LOCALAPPDATA,
  'Packages',
  'Microsoft.WindowsTerminal_8wekyb3d8bbwe',
  'LocalState',
  'settings.json'
);

if (!fs.existsSync(wtSettingsPath)) {
  console.log('\n  Windows Terminal not found.');
  console.log('  Please install Windows Terminal from the Microsoft Store first.\n');
  process.exit(1);
}

// Run the PowerShell installer
console.log('\n  Installing Matrix Shader profiles...\n');

const script = path.join(__dirname, '..', 'install.ps1');
const result = spawnSync('powershell', ['-ExecutionPolicy', 'Bypass', '-File', script], {
  stdio: 'inherit',
  shell: true
});

if (result.status !== 0) {
  console.log('\n  Installation failed. Please run install.ps1 manually.\n');
  process.exit(1);
}

console.log('\n  Matrix Shader installed successfully!');
console.log('  Run "wakeupneo" to start.\n');
