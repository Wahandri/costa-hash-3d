// Agente LLM (DeepSeek) que juega a COSTA HASH 3D via DebugBridge.
// Uso: node llm-agent.mjs [--seconds 180] [--step 7] [--out out/llm] [--dry]
// Requiere DEEPSEEK_API_KEY (entorno o /opt/server/.env).
import net from 'node:net';
import { mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';

const args = process.argv.slice(2);
const getArg = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
const hasFlag = (name) => args.includes(name);
const SECONDS = Number(getArg('--seconds', 180));
const STEP_MS = Number(getArg('--step', 7)) * 1000;
const PORT = Number(getArg('--port', 9099));
const OUT = getArg('--out', new URL('./out/llm/', import.meta.url).pathname);
const DRY = hasFlag('--dry');
mkdirSync(OUT, { recursive: true });

function loadKey() {
  if (process.env.DEEPSEEK_API_KEY) return process.env.DEEPSEEK_API_KEY;
  try {
    const env = readFileSync('/opt/server/.env', 'utf8');
    const m = env.match(/DEEPSEEK_API_KEY\s*=\s*(.+)/);
    if (m) return m[1].trim().replace(/^["']|["']$/g, '');
  } catch { /* ignore */ }
  return '';
}
const API_KEY = loadKey();

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

const SYSTEM = `Eres un jugador de COSTA HASH 3D. Objetivo: ganar dinero vendiendo posturas
a clientes, sin que te pille la policia, y subir de rango.
Responde SOLO con un objeto JSON: {"action":"...","reason":"..."}.
Acciones validas:
 - "goto_client": ir al cliente mas cercano (para venderle)
 - "sell": vender (solo si estas junto a un cliente)
 - "buy": comprar una placa de posturas
 - "flee": huir de la policia
 - "wait": esperar
Elige la accion mas util segun el estado.`;

async function askLLM(state) {
  const prompt = JSON.stringify(state);
  const res = await fetch('https://api.deepseek.com/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${API_KEY}` },
    body: JSON.stringify({
      model: 'deepseek-chat',
      messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: prompt }],
      temperature: 0.4,
      max_tokens: 120,
    }),
  });
  if (!res.ok) throw new Error(`API ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const text = data.choices?.[0]?.message?.content || '';
  const m = text.match(/\{[\s\S]*\}/);
  return m ? JSON.parse(m[0]) : { action: 'wait', reason: 'sin json' };
}

function fallback(state) {
  if (state.police > 0) return { action: 'flee', reason: 'fallback' };
  if (state.posturas <= 0) return { action: 'buy', reason: 'fallback' };
  if (state.nearest_client && dist2(state.nearest_client, state.pos) < 4) return { action: 'sell', reason: 'fallback' };
  if (state.nearest_client) return { action: 'goto_client', reason: 'fallback' };
  return { action: 'wait', reason: 'fallback' };
}

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
const t0 = Date.now();

async function exec(state, decision) {
  const a = decision.action;
  if (a === 'goto_client' && state.nearest_client) {
    await request(sock, { cmd: 'goto', x: state.nearest_client[0], z: state.nearest_client[2] });
  } else if (a === 'sell') {
    await request(sock, { cmd: 'stop' });
    await request(sock, { cmd: 'action' });
  } else if (a === 'buy') {
    await request(sock, { cmd: 'stop' });
    await request(sock, { cmd: 'buy_placa' });
  } else if (a === 'flee' && state.police_pos && state.police_pos.length) {
    const p = state.police_pos[0];
    await request(sock, { cmd: 'goto', x: state.pos[0] - (p[0] - state.pos[0]), z: state.pos[2] - (p[2] - state.pos[2]) });
  } else {
    await request(sock, { cmd: 'stop' });
  }
}

while ((Date.now() - t0) / 1000 < SECONDS) {
  const st = (await request(sock, { cmd: 'state' })).state;
  metrics.push({
    t: Number(((Date.now() - t0) / 1000).toFixed(1)),
    money: st.money, posturas: st.posturas, xp: st.xp, rank: st.rank,
    wanted: st.wanted_level, clients: st.clients, police: st.police,
    pos: st.pos, district: st.district,
  });

  let decision;
  try {
    decision = DRY || !API_KEY ? fallback(st) : await askLLM(st);
  } catch (e) {
    console.log('[llm] error:', e.message, '-> fallback');
    decision = fallback(st);
  }
  events.push({ t: ((Date.now() - t0) / 1000).toFixed(1), name: `dec:${decision.action}`, reason: decision.reason });
  console.log(`[dec] ${decision.action} (${decision.reason}) | money=${st.money} posturas=${st.posturas} wanted=${st.wanted_level}`);
  await exec(st, decision);
  await sleep(STEP_MS);
}

const summary = {
  seconds: Number(((Date.now() - t0) / 1000).toFixed(1)),
  start: metrics[0], end: metrics[metrics.length - 1],
  max_money: Math.max(...metrics.map((m) => m.money)),
  max_xp: Math.max(...metrics.map((m) => m.xp)),
  max_rank: Math.max(...metrics.map((m) => m.rank)),
  max_wanted: Math.max(...metrics.map((m) => m.wanted)),
  agent: DRY || !API_KEY ? 'fallback' : 'deepseek',
  samples: metrics.length,
};
writeFileSync(`${OUT}/metrics.json`, JSON.stringify(metrics, null, 1));
writeFileSync(`${OUT}/eventos.json`, JSON.stringify(events, null, 1));
writeFileSync(`${OUT}/resumen.json`, JSON.stringify(summary, null, 1));
console.log('resumen:', JSON.stringify(summary));
sock.end();
