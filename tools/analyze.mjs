// Genera INFORME.md a partir de una sesion de playtest (metrics/eventos/resumen).
// Uso: node analyze.mjs [--out out/bot]
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

const args = process.argv.slice(2);
const getArg = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
const OUT = getArg('--out', new URL('./out/bot/', import.meta.url).pathname);

function read(name, def) {
  const p = `${OUT}/${name}`;
  if (!existsSync(p)) return def;
  return JSON.parse(readFileSync(p, 'utf8'));
}

const metrics = read('metrics.json', []);
const events = read('eventos.json', []);
const resumen = read('resumen.json', {});

if (metrics.length === 0) {
  console.error(`No hay metrics.json en ${OUT}. Ejecuta antes bot.mjs o llm-agent.mjs.`);
  process.exit(1);
}

const first = metrics[0];
const last = metrics[metrics.length - 1];
const minutes = (resumen.seconds || last.t || 1) / 60;
const eurPerMin = ((last.money - first.money) / minutes).toFixed(0);
const xpPerMin = ((last.xp - first.xp) / minutes).toFixed(0);
const noStock = metrics.filter((m) => m.posturas === 0).length;
const pctNoStock = ((noStock / metrics.length) * 100).toFixed(0);
const eventCount = (name) => events.filter((e) => e.name === name).length;

const lines = [];
lines.push('# INFORME DE PLAYTEST — COSTA HASH 3D');
lines.push('');
lines.push(`- Duracion: ${resumen.seconds || last.t} s (${metrics.length} muestras)`);
lines.push(`- Distrito: ${last.district}`);
lines.push('');
lines.push('## Resumen');
lines.push(`- Dinero: ${first.money} -> ${last.money} EUR (${eurPerMin} EUR/min)`);
lines.push(`- XP: ${first.xp} -> ${last.xp} (${xpPerMin} XP/min) | Rango ${first.rank} -> ${last.rank}`);
lines.push(`- Max buscado: ${resumen.max_wanted} estrellas`);
lines.push(`- Tiempo sin posturas: ${pctNoStock}% de la sesion`);
lines.push('');
lines.push('## Metricas por minuto');
lines.push('| min | dinero | posturas | XP | rango | buscado | clientes | poli |');
lines.push('|-----|--------|----------|----|-------|---------|----------|------|');
for (const m of metrics) {
  if (m.t % 5 !== 0 && m.t !== last.t) continue;
  lines.push(`| ${m.t}s | ${m.money} | ${m.posturas} | ${m.xp} | ${m.rank} | ${m.wanted} | ${m.clients} | ${m.police} |`);
}
lines.push('');
lines.push('## Eventos');
lines.push(`- Subidas de rango: ${eventCount('sube_rango')}`);
lines.push(`- Se quedo sin posturas: ${eventCount('sin_posturas')}`);
lines.push(`- Persecuciones: ${eventCount('policia')} | Escapadas: ${eventCount('escapo')}`);
lines.push('');
lines.push('## Lectura de diseno');
const tips = [];
if (Number(eurPerMin) < 60) tips.push('El ritmo de ingresos es bajo: revisar precio de venta o frecuencia de clientes.');
if (Number(pctNoStock) > 30) tips.push('Demasiado tiempo sin stock: los clientes aparecen mas rapido de lo que se repone.');
if (eventCount('sube_rango') === 0 && last.xp < 150) tips.push('La primera subida de rango tarda mucho: bajar el XP de rango 2 o dar mas XP por venta.');
if (resumen.max_wanted >= 3) tips.push('La policia escala rapido: vigilar la curva de calor por venta.');
if (tips.length === 0) tips.push('Ritmo razonable en esta sesion.');
for (const t of tips) lines.push(`- ${t}`);
lines.push('');
lines.push(`> Generado automaticamente por analyze.mjs a partir de ${OUT}`);
lines.push('');

writeFileSync(`${OUT}/INFORME.md`, lines.join('\n'));
console.log(`Informe escrito en ${OUT}/INFORME.md`);
console.log(lines.slice(0, 12).join('\n'));
