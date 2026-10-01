// Bot de reglas que juega solo a COSTA HASH 3D via DebugBridge y registra metricas.
// Uso: node bot.mjs [--seconds 120] [--port 9099] [--out out/bot]
import net from 'node:net';
import { mkdirSync, writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const getArg = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
const SECONDS = Number(getArg('--seconds', 120));
const PORT = Number(getArg('--port', 9099));
const OUT = getArg('--out', new URL('./out/bot/', import.meta.url).pathname);
mkdirSync(OUT, { recursive: true });

function connect() {
  return new Promise((resolve, reject) => {
    const s = net.createConnection({ port: PORT, host: '127.0.0.1' }, () => resolve(s));
    s.on('error', reject);
  });
}
let buffer = '';
const pending = [];
function request(sock, obj) {
  return new Promise((resolve) => { pending.push(resolve); sock.write(JSON.stringify(obj) + '\n'); });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const dist2 = (a, b) => Math.hypot(a[0] - b[0], a[2] - b[2]);

const sock = await connect();
sock.on('data', (chunk) => {
  buffer += chunk.toString('utf8');
  let i;
  while ((i = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, i); buffer = buffer.slice(i + 1);
    if (line.trim()) { const r = pending.shift(); if (r) r(JSON.parse(line)); }
  }
});

const metrics = [];
const events = [];
let last = { money: 0, posturas: 0, rank: 1, wanted: 0 };
const t0 = Date.now();

function logEvent(name, extra = {}) {
  events.push({ t: ((Date.now() - t0) / 1000).toFixed(1), name, ...extra });
  console.log(`[evento] ${name}`, JSON.stringify(extra));
}

while ((Date.now() - t0) / 1000 < SECONDS) {
  let st;
  try {
    st = (await request(sock, { cmd: 'state' })).state;
  } catch {
    await sleep(1000);
    continue;
  }
  const t = ((Date.now() - t0) / 1000).toFixed(1);
  metrics.push({
    t: Number(t), money: st.money, posturas: st.posturas, xp: st.xp, rank: st.rank,
    wanted: st.wanted_level, clients: st.clients, police: st.police,
    pos: st.pos, district: st.district,
  });

  if (st.money > last.money && last.money !== 0) { /* venta */ }
  if (st.rank > last.rank) logEvent('sube_rango', { rank: st.rank });
  if (st.posturas === 0 && last.posturas > 0) logEvent('sin_posturas');
  if (st.wanted_level > last.wanted && st.wanted_level > 0) logEvent('policia', { nivel: st.wanted_level });
  if (st.wanted_level === 0 && last.wanted > 0) logEvent('escapo');
  last = { money: st.money, posturas: st.posturas, rank: st.rank, wanted: st.wanted_level };

  // --- Decision (perfil curioso pero funcional) ---
  const police_away = st.police > 0 && (st.police_pos || []).some((p) => dist2(p, st.pos) < 45);
  if (police_away) {
    const p = st.police_pos[0];
    await request(sock, { cmd: 'goto', x: st.pos[0] - (p[0] - st.pos[0]), z: st.pos[2] - (p[2] - st.pos[2]) });
  } else if (st.posturas <= 0) {
    await request(sock, { cmd: 'stop' });
    await request(sock, { cmd: 'buy_placa' });
  } else if (st.nearest_client && st.nearest_client.length === 3) {
    const d = dist2(st.nearest_client, st.pos);
    if (d < 4.0) {
      await request(sock, { cmd: 'stop' });
      await request(sock, { cmd: 'action' });
    } else {
      await request(sock, { cmd: 'goto', x: st.nearest_client[0], z: st.nearest_client[2] });
    }
  } else {
    await request(sock, { cmd: 'stop' });
  }

  await sleep(500);
}

const summary = {
  seconds: Number(((Date.now() - t0) / 1000).toFixed(1)),
  start: metrics[0],
  end: metrics[metrics.length - 1],
  max_money: Math.max(...metrics.map((m) => m.money)),
  max_xp: Math.max(...metrics.map((m) => m.xp)),
  max_rank: Math.max(...metrics.map((m) => m.rank)),
  max_wanted: Math.max(...metrics.map((m) => m.wanted)),
  sales_proxy: (metrics[metrics.length - 1]?.money || 0) - (metrics[0]?.money || 0),
  samples: metrics.length,
};
writeFileSync(`${OUT}/metrics.json`, JSON.stringify(metrics, null, 1));
writeFileSync(`${OUT}/eventos.json`, JSON.stringify(events, null, 1));
writeFileSync(`${OUT}/resumen.json`, JSON.stringify(summary, null, 1));
console.log('resumen:', JSON.stringify(summary));
sock.end();
