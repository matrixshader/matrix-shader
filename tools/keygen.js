#!/usr/bin/env node
// keygen.js - Generate REDPILL license keys for testing and batch creation
// Usage:
//   node keygen.js                    # Generate 1 key
//   node keygen.js 10                 # Generate 10 keys
//   node keygen.js 500 > batch.txt    # Generate 500 keys to file

import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

// Read the license secret
const secretPath = path.join(__dirname, '..', 'MatrixShader', 'license-secret.key');
if (!fs.existsSync(secretPath)) {
  console.error(`ERROR: license-secret.key not found at ${secretPath}`);
  process.exit(1);
}
const SECRET = fs.readFileSync(secretPath, 'utf8').trim();

function toBase36(bytes, offset, length) {
  let result = '';
  for (let i = 0; i < length; i++) {
    const idx = (offset + i < bytes.length) ? bytes[offset + i] % 36 : 0;
    result += CHARS[idx];
  }
  return result;
}

function generateKey(seed) {
  const hash = crypto.createHash('sha256').update(seed).digest();
  const g1 = toBase36(hash, 0, 4);
  const g2 = toBase36(hash, 4, 4);
  const g3 = toBase36(hash, 8, 4);

  const payload = `REDPILL-${g1}-${g2}-${g3}`;
  const hmac = crypto.createHmac('sha256', SECRET).update(payload).digest();
  const sig = toBase36(hmac, 0, 4);

  return `${payload}-${sig}`;
}

const count = parseInt(process.argv[2]) || 1;

for (let i = 0; i < count; i++) {
  // Use timestamp + counter + random for unique seeds
  const seed = `LS-keygen-${Date.now()}-${i}-${crypto.randomBytes(8).toString('hex')}`;
  console.log(generateKey(seed));
}
