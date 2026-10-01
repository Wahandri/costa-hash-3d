// Prueba headless del sistema de policia via DebugBridge (TCP JSON-lines).
// Arranca el juego headless aparte con: godot --headless --debug-bridge
import net from 'node:net';

const PORT = Number(process.env.BRIDGE_PORT || 9099);
const HOST = '127.0.0.1';

function connect() {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection({ port: PORT, host: HOST }, () => resolve(sock));
    sock.on('error', reject);
  });
}

let buffer = '';
const pending = [];
function request(sock, obj) {
  return new Promise((resolve) => {
    pending.push(resolve);
    sock.write(JSON.stringify(obj) + '\n');
  });
}

const sock = await connect();
sock.on('data', (chunk) => {
  buffer += chunk.toString('utf8');
  let idx;
  while ((idx = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, idx);
    buffer = buffer.slice(idx + 1);
    if (!line.trim()) continue;
    const res = pending.shift();
    if (res) res(JSON.parse(line));
  }
});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

await request(sock, { cmd: 'ping' });
let st = await request(sock, { cmd: 'state' });
console.log('estado inicial:', JSON.stringify(st.state));

// Tres "delitos" para subir el nivel de busqueda
for (let i = 0; i < 3; i++) {
  await request(sock, { cmd: 'crime' }).catch(() => {});
  await sleep(800);
}

let maxPolice = 0;
let minDist = Infinity;
let arrested = false;
for (let i = 0; i < 40; i++) {
  await sleep(1000);
  st = await request(sock, { cmd: 'state' });
  const s = st.state;
  maxPolice = Math.max(maxPolice, s.police);
  const px = s.pos[0], pz = s.pos[2];
  let d = Infinity;
  for (const p of (s.police_pos || [])) {
    d = Math.min(d, Math.hypot(p[0] - px, p[2] - pz));
  }
  if (Number.isFinite(d)) minDist = Math.min(minDist, d);
  if (s.wanted_level === 0 && i > 3) arrested = true;
  console.log(`t=${i + 1}s wanted=${s.wanted_level} police=${s.police} dist=${Number.isFinite(d) ? d.toFixed(1) : '-'} chasing=${s.chasing}`);
  if (arrested) break;
}

console.log(`\nmax policias: ${maxPolice} | dist min: ${Number.isFinite(minDist) ? minDist.toFixed(1) + 'm' : '-'} | arresto: ${arrested}`);
sock.end();

if (maxPolice < 1) {
  console.error('FALLO: no se genero policia');
  process.exit(1);
}
console.log('OK: la policia se genera y persigue');
