// Playtest headless de la economia: comprar placa, vender a clientes, subir XP.
import net from 'node:net';

const PORT = Number(process.env.BRIDGE_PORT || 9099);
function connect() {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection({ port: PORT, host: '127.0.0.1' }, () => resolve(sock));
    sock.on('error', reject);
  });
}
let buffer = '';
const pending = [];
function request(sock, obj) {
  return new Promise((resolve) => { pending.push(resolve); sock.write(JSON.stringify(obj) + '\n'); });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const sock = await connect();
sock.on('data', (chunk) => {
  buffer += chunk.toString('utf8');
  let idx;
  while ((idx = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, idx); buffer = buffer.slice(idx + 1);
    if (line.trim()) { const r = pending.shift(); if (r) r(JSON.parse(line)); }
  }
});

let st = await request(sock, { cmd: 'state' });
console.log('inicio:', JSON.stringify({ money: st.state.money, posturas: st.state.posturas, xp: st.state.xp, rank: st.state.rank, clients: st.state.clients }));

let sales = 0, earned = 0;
for (let i = 0; i < 30; i++) {
  await sleep(1000);
  const res = await request(sock, { cmd: 'sell' });
  if (res.ok && res.result && res.result.ok) { sales++; earned += res.result.earned; }
  if (i % 5 === 0) {
    const s = (await request(sock, { cmd: 'state' })).state;
    console.log(`t=${i + 1}s money=${s.money} posturas=${s.posturas} xp=${s.xp} rank=${s.rank} clients=${s.clients} sales=${sales}`);
  }
  if (i === 5) {
    const b = await request(sock, { cmd: 'buy_placa' });
    console.log('buy_placa:', JSON.stringify(b));
  }
}
st = (await request(sock, { cmd: 'state' })).state;
console.log('final:', JSON.stringify({ money: st.money, posturas: st.posturas, xp: st.xp, rank: st.rank }));
console.log(`ventas: ${sales} | ganado: ${earned}`);
sock.end();

if (sales < 1) { console.error('FALLO: no hubo ventas'); process.exit(1); }
if (st.xp <= 0) { console.error('FALLO: no subio XP'); process.exit(1); }
console.log('OK: economia funciona (ventas + XP)');
