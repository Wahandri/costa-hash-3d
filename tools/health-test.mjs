// Verifica el sistema de salud/hospital via DebugBridge (puerto 9099).
import net from 'net';

const PORT = Number(process.env.BRIDGE_PORT || 9099);
const sock = net.connect(PORT, '127.0.0.1');
let buf = '';
sock.on('data', (d) => { buf += d.toString(); });

function rpc(obj) {
  return new Promise((resolve) => {
    const h = () => {
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i).trim();
        buf = buf.slice(i + 1);
        if (line) { sock.off('data', h); resolve(JSON.parse(line)); return; }
      }
    };
    sock.on('data', h);
    sock.write(JSON.stringify(obj) + '\n');
  });
}

await new Promise((r) => sock.on('connect', r));
const before = (await rpc({ cmd: 'state' })).state;
await rpc({ cmd: 'damage', amount: 200 });   // muerte instantanea
await new Promise((r) => setTimeout(r, 600));
const after = (await rpc({ cmd: 'state' })).state;

console.log('money:', before.money, '->', after.money);
console.log('health:', before.health, '->', after.health);
console.log('pos:', before.pos.map((v) => v.toFixed(1)).join(','), '->', after.pos.map((v) => v.toFixed(1)).join(','));
const ok = after.health === 100 && after.money < before.money;
console.log(ok ? 'OK: hospital (pierde dinero, recupera vida, reaparece)' : 'FALLO');
sock.end();
process.exit(ok ? 0 : 1);
