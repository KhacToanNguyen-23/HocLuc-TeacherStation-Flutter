import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { createServer } from 'node:net';
import { request } from 'node:http';
import { fileURLToPath } from 'node:url';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const fixture = await mkdtemp(join(tmpdir(), 'companion-contract-'));
await mkdir(join(fixture, 'app/build/web'), { recursive: true });
await writeFile(join(fixture, 'app/build/web/index.html'), '<h1>fixture</h1>');
const listener = createServer(); listener.listen(0, '127.0.0.1'); await once(listener, 'listening');
const port = listener.address().port; await new Promise(resolve => listener.close(resolve));
const url = `http://127.0.0.1:${port}`;
let child;
async function start() {
  child = spawn('java', ['-jar', join(root, 'service/target/companion-service-0.1.0.jar'), fixture, String(port)], { stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
  let output = ''; child.stderr.on('data', b => output += b);
  for (let i = 0; i < 80; i++) {
    if (child.exitCode !== null) throw new Error(output || 'Java exited');
    try { const r = await fetch(`${url}/api/bootstrap`); if (r.ok) return (await r.json()).token; } catch { }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error('Java did not become ready');
}
async function stop() {
  if (child?.exitCode === null) { const ended = once(child, 'exit'); child.kill(); await ended; }
}
try {
  let token = await start();
  const headers = () => ({ 'X-Companion-Token': token, 'Content-Type': 'application/json' });
  assert.equal((await fetch(`${url}/api/lesson`)).status, 401);
  assert.equal((await fetch(`${url}/api/bootstrap`, { headers: { Origin: 'https://unrelated.example' } })).status, 403);
  const wrongHost = await new Promise((resolve, reject) => {
    const req = request(url, { headers: { Host: 'unrelated.example' } }, res => { res.resume(); res.on('end', () => resolve(res.statusCode)); });
    req.on('error', reject); req.end();
  });
  assert.equal(wrongHost, 403);
  assert.equal((await fetch(`${url}/`)).status, 200);
  const capabilities = await (await fetch(`${url}/api/capabilities`, { headers: headers() })).json();
  assert.equal(capabilities.virtualCamera, false); assert.equal(capabilities.aiStreaming, false);
  const payload = { title: 'Bài giảng tiếng Việt', notes: 'Chỉ giáo viên xem', pages: [[], [], []] };
  assert.equal((await fetch(`${url}/api/lesson`, { method: 'PUT', headers: headers(), body: JSON.stringify(payload) })).status, 200);
  assert.deepEqual(await (await fetch(`${url}/api/lesson`, { headers: headers() })).json(), payload);
  assert.equal((await fetch(`${url}/api/lesson`, { method: 'PUT', headers: headers(), body: '[]' })).status, 400);
  assert.equal((await fetch(`${url}/api/lesson`, { method: 'PUT', headers: headers(), body: '{' })).status, 400);
  assert.equal((await fetch(`${url}/api/output/start`, { method: 'POST', headers: headers() })).status, 501);
  assert.ok(Array.isArray((await (await fetch(`${url}/api/devices`, { headers: headers() })).json()).microphones));
  const previousToken = token;
  await stop(); token = await start();
  assert.notEqual(token, previousToken);
  assert.equal((await fetch(`${url}/api/lesson`, { headers: { 'X-Companion-Token': previousToken } })).status, 401);
  assert.deepEqual(await (await fetch(`${url}/api/lesson`, { headers: headers() })).json(), payload);
  console.log('PASS: local authentication, origin/host, capabilities, UTF-8 persistence, restart, invalid JSON, device contract, unsupported output.');
} finally { await stop(); }
