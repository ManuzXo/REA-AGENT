import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const root = fileURLToPath(new URL('../', import.meta.url));
const snapshot = process.argv[2];
if (!snapshot || process.argv.length !== 3) throw new Error('Uso: node scripts/test-ghidra.mjs .rea/mcp/ghidra.json');
const directory = resolve(root, '.tools', 'ghidra-smoke', new Date().toISOString().replace(/[:.]/g, '-'));
mkdirSync(directory, { recursive: true });
const target = resolve(directory, 'returns-42.exe');
const binary = Buffer.alloc(1024);
binary.write('MZ');
binary.writeUInt32LE(0x80, 0x3c);
binary.write('PE\0\0', 0x80);
binary.writeUInt16LE(0x8664, 0x84);
binary.writeUInt16LE(1, 0x86);
binary.writeUInt16LE(0xf0, 0x94);
binary.writeUInt16LE(0x22, 0x96);
const optional = 0x98;
binary.writeUInt16LE(0x20b, optional);
binary.writeUInt32LE(512, optional + 4);
binary.writeUInt32LE(0x1000, optional + 16);
binary.writeUInt32LE(0x1000, optional + 20);
binary.writeBigUInt64LE(0x140000000n, optional + 24);
binary.writeUInt32LE(0x1000, optional + 32);
binary.writeUInt32LE(512, optional + 36);
binary.writeUInt16LE(6, optional + 40);
binary.writeUInt16LE(6, optional + 48);
binary.writeUInt32LE(0x2000, optional + 56);
binary.writeUInt32LE(512, optional + 60);
binary.writeUInt16LE(3, optional + 68);
binary.writeBigUInt64LE(0x100000n, optional + 72);
binary.writeBigUInt64LE(0x1000n, optional + 80);
binary.writeBigUInt64LE(0x100000n, optional + 88);
binary.writeBigUInt64LE(0x1000n, optional + 96);
binary.writeUInt32LE(16, optional + 108);
const section = optional + 0xf0;
binary.write('.text', section);
binary.writeUInt32LE(6, section + 8);
binary.writeUInt32LE(0x1000, section + 12);
binary.writeUInt32LE(512, section + 16);
binary.writeUInt32LE(512, section + 20);
binary.writeUInt32LE(0x60000020, section + 36);
binary.set([0xb8, 0x2a, 0, 0, 0, 0xc3], 512);
writeFileSync(target, binary);
const callsPath = resolve(directory, 'calls.json');
const output = resolve(directory, 'evidence.json');
writeFileSync(callsPath, JSON.stringify([
  { name: 'open_binary', arguments: { path: target, provider_id: 'ghidra' } },
  { name: 'list_procedures', arguments: {} },
  { name: 'batch_decompile', arguments: { addresses: ['0x140001000'] } },
  { name: 'close_binary', arguments: {} },
], null, 2));
console.log('Analisi statica di una fixture PE x64 generata dal test. Il campione non viene eseguito.');
const probe = spawnSync(process.execPath, [resolve(root, 'scripts/test-mcp.mjs'), '--snapshot', resolve(snapshot), '--calls', callsPath, '--output', output, '--timeout-ms', '240000'], { stdio: 'inherit', windowsHide: true });
if (probe.error) throw probe.error;
if (probe.status !== 0) throw new Error(`Verifica Ghidra fallita. Evidenze in ${directory}`);
const evidence = JSON.parse(readFileSync(output, 'utf8'));
const decompile = evidence.calls.find(call => call.name === 'batch_decompile');
if (!/return\s+(?:0x2a|42)\s*;/i.test(JSON.stringify(decompile?.result))) throw new Error(`Pseudocodice atteso return 42 assente. Leggi ${output}`);
const summary = { target, sha256: createHash('sha256').update(binary).digest('hex'), provider: 'ghidra', address: '0x140001000', expected: 'return 42', executedTarget: false, passed: true, evidence: output };
writeFileSync(resolve(directory, 'summary.json'), JSON.stringify(summary, null, 2));
console.log(`PASS: Ghidra decompila 0x140001000 e restituisce 42. Evidenze in ${directory}`);
