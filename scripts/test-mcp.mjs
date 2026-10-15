import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const options = {};
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index];
  if (!['--entry', '--node', '--snapshot', '--server', '--calls', '--output', '--dump-tools', '--timeout-ms'].includes(key) || !process.argv[index + 1] || options[key]) {
    throw new Error('Uso: node scripts/test-mcp.mjs (--entry CLI [--node NODE] | --snapshot JSON [--server NOME]) [--calls JSON] [--output JSON] [--dump-tools JSON] [--timeout-ms N]');
  }
  options[key] = process.argv[index + 1];
}
if (Boolean(options['--entry']) === Boolean(options['--snapshot'])) throw new Error('Scegli --entry oppure --snapshot.');
let launch;
if (options['--snapshot']) {
  const { mcpServers } = JSON.parse(readFileSync(resolve(options['--snapshot']), 'utf8').replace(/^\uFEFF/, ''));
  const name = options['--server'] || Object.keys(mcpServers)[0];
  launch = mcpServers[name];
  if (!launch || !launch.command || !Array.isArray(launch.args)) throw new Error('Snapshot MCP stdio non valido.');
} else {
  launch = { command: options['--node'] || process.execPath, args: [resolve(options['--entry']), 'mcp'], env: {} };
}
if (existsSync(resolve(root, 'rea.bat'))) throw new Error('rea.bat nasconde il comando upstream.');
const timeout = Number(options['--timeout-ms'] || 45000);
if (!Number.isInteger(timeout) || timeout < 100 || timeout > 600000) throw new Error('Timeout non valido.');
const extraCalls = options['--calls'] ? JSON.parse(readFileSync(resolve(options['--calls']), 'utf8').replace(/^\uFEFF/, '')) : [];
if (!Array.isArray(extraCalls)) throw new Error('--calls richiede un array di {name, arguments}.');
const child = spawn(launch.command, launch.args, { cwd: root, env: { ...process.env, ...launch.env }, stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
let buffer = '';
let stderr = '';
let nextId = 1;
const pending = new Map();
const evidence = { launch, checks: [], calls: [] };
let failed = false;
let finished = false;
const fail = error => {
  if (failed) return;
  failed = true;
  console.error(`FAIL: ${error.message || error}${stderr ? `\n${stderr}` : ''}`);
  process.exitCode = 1;
  for (const task of pending.values()) task.reject(error);
  pending.clear();
  child.stdin.destroy();
  child.kill();
};
const timer = setTimeout(() => fail(new Error('MCP timeout.')), timeout);
child.stderr.on('data', data => { stderr = (stderr + data.toString()).slice(-8000); });
child.on('error', fail);
child.stdin.on('error', fail);
child.on('exit', code => {
  clearTimeout(timer);
  if (!finished || code !== 0) fail(new Error(`MCP exited ${code}.`));
});
child.stdout.on('data', data => {
  buffer += data.toString();
  let newline;
  while ((newline = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, newline).trim();
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    let message;
    try { message = JSON.parse(line); } catch { fail(new Error('MCP stdout contiene testo non JSON.')); continue; }
    const task = pending.get(message.id);
    if (!task) continue;
    pending.delete(message.id);
    if (message.error) task.reject(new Error(JSON.stringify(message.error)));
    else task.resolve(message.result);
  }
});
const request = (method, params) => new Promise((resolveRequest, reject) => {
  const id = nextId++;
  pending.set(id, { resolve: resolveRequest, reject });
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
});
try {
  evidence.initialize = await request('initialize', { protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'rea-repository-verification', version: '1.0.0' } });
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
  const tools = [];
  let cursor;
  do {
    const page = await request('tools/list', cursor ? { cursor } : {});
    tools.push(...page.tools);
    cursor = page.nextCursor;
  } while (cursor);
  for (const name of ['binary_session', 'inspect_artifact', 'open_binary']) {
    if (!tools.some(tool => tool.name === name)) throw new Error(`Strumento REA assente: ${name}`);
  }
  if (options['--dump-tools']) writeFileSync(resolve(options['--dump-tools']), JSON.stringify(tools, null, 2));
  const calls = [{ name: 'binary_session', arguments: {} }, ...extraCalls];
  for (const call of calls) {
    if (!call || typeof call.name !== 'string' || !tools.some(tool => tool.name === call.name)) throw new Error('Chiamata a strumento non disponibile.');
    const result = await request('tools/call', { name: call.name, arguments: call.arguments || {} });
    evidence.calls.push({ ...call, result });
    if (result.isError) throw new Error(`Strumento ${call.name} fallito: ${JSON.stringify(result.content).slice(0, 1500)}`);
    if (call.expectText && !JSON.stringify(result).includes(call.expectText)) throw new Error(`${call.name} non contiene il risultato atteso ${call.expectText}.`);
    console.log(`PASS: tools/call ${call.name}.`);
  }
  evidence.checks = ['initialize', `tools/list ${tools.length}`, 'tools/call binary_session'];
  console.log(`PASS: MCP initialize, tools/list ${tools.length} tools, ${calls.length} tool calls.`);
  finished = true;
  child.stdin.end();
} catch (error) {
  fail(error);
} finally {
  if (options['--output']) writeFileSync(resolve(options['--output']), JSON.stringify(evidence, null, 2));
}
