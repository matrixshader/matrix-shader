#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

const exe = path.join(__dirname, 'native', 'bluepill.exe');
const child = spawn(exe, process.argv.slice(2), { stdio: 'inherit' });
child.on('exit', (code) => process.exit(code || 0));
