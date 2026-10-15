import { spawn } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const cache = process.argv[2];
if (!cache) throw new Error('Usage: node scripts/test-mcp.mjs PATH_TO_EXISTING_NPM_CACHE');
if (existsSync(resolve(root, 'rea.bat'))) throw new Error('rea.bat shadows the upstream npm executable.');
const { reaVersion } = JSON.parse(readFileSync(resolve(root, 'config/rea.json'), 'utf8').replace(/^\uFEFF/, ''));
const child = spawn('cmd.exe', ['/d', '/c', 'npx.cmd', '--yes', `rea-agents@${reaVersion}`, 'mcp'], {
  cwd: root,
  env: { ...process.env, npm_config_cache: resolve(cache), npm_config_offline: 'true' },
  stdio: ['pipe', 'pipe', 'pipe'],
});
let buffer = '';
let stderr = '';
let verified = false;
const timer = setTimeout(() => {
  console.error('FAIL: MCP handshake timed out.');
  child.stdin.end();
  process.exitCode = 1;
}, 45000);
child.stderr.on('data', data => { stderr = (stderr + data.toString()).slice(-4000); });
child.on('error', error => { clearTimeout(timer); console.error(error); process.exitCode = 1; });
child.on('exit', code => {
  clearTimeout(timer);
  if (!verified || code !== 0) {
    console.error(`FAIL: MCP exited ${code}. ${stderr}`);
    process.exitCode = 1;
  }
});
const send = message => child.stdin.write(JSON.stringify(message) + '\n');
child.stdout.on('data', data => {
  buffer += data.toString();
  let newline;
  while ((newline = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, newline).trim();
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    let message;
    try { message = JSON.parse(line); } catch { console.error('FAIL: non-JSON stdout from MCP.'); child.stdin.end(); process.exitCode = 1; continue; }
    if (message.error) { console.error(message.error); child.stdin.end(); process.exitCode = 1; continue; }
    if (message.id === 1) {
      send({ jsonrpc: '2.0', method: 'notifications/initialized' });
      send({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} });
    }
    if (message.id === 2) {
      const names = message.result.tools.map(tool => tool.name);
      if (!names.includes('binary_session') || !names.includes('inspect_artifact')) {
        console.error('FAIL: expected REA tools absent.');
        process.exitCode = 1;
      } else {
        verified = true;
        console.log(`PASS: direct Windows MCP registration, initialize and tools/list, ${names.length} tools.`);
      }
      clearTimeout(timer);
      child.stdin.end();
    }
  }
});
send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'rea-workspace-check', version: '1.0.0' } } });
