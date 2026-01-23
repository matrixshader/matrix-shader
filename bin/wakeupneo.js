#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

const script = path.join(__dirname, '..', 'matrix_setup.ps1');
const ps = spawn('powershell', ['-ExecutionPolicy', 'Bypass', '-File', script], {
  stdio: 'inherit',
  shell: true
});

ps.on('close', (code) => {
  process.exit(code);
});
