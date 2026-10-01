// Smoke test: carga el build web de COSTA HASH 3D en Chrome headless,
// comprueba que arranca (WebGL/canvas), recoge errores de consola y guarda
// una captura para revision visual.
//
// Uso: node smoke.mjs [url] [--out DIR]

import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';

const args = process.argv.slice(2);
const url = args.find((a) => a.startsWith('http')) || 'http://localhost:3017/';
const outIdx = args.indexOf('--out');
const outDir = outIdx >= 0 ? args[outIdx + 1] : new URL('./out/', import.meta.url).pathname;
mkdirSync(outDir, { recursive: true });

const CHROME = process.env.CHROME || '/usr/bin/google-chrome';

const browser = await chromium.launch({
  executablePath: CHROME,
  headless: true,
  args: [
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
  ],
});

const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

const errors = [];
const warnings = [];
const logs = [];
page.on('console', (msg) => {
  const t = msg.type();
  const text = `[${t}] ${msg.text()}`;
  if (t === 'error') errors.push(text);
  else if (t === 'warning') warnings.push(text);
  else logs.push(text);
});
page.on('pageerror', (err) => errors.push(`[pageerror] ${err.message}`));
page.on('requestfailed', (req) => errors.push(`[requestfailed] ${req.url()} ${req.failure()?.errorText}`));

console.log('cargando', url);
await page.goto(url, { waitUntil: 'load', timeout: 120000 });

// Espera a que Godot arranque y construya el mundo
await page.waitForTimeout(12000);

const info = await page.evaluate(() => {
  const canvas = document.querySelector('#canvas, canvas');
  return {
    title: document.title,
    hasCanvas: !!canvas,
    canvasW: canvas ? canvas.width : 0,
    canvasH: canvas ? canvas.height : 0,
    gl: (() => {
      try {
        const c = document.createElement('canvas');
        const g = c.getContext('webgl2');
        return g ? 'webgl2' : 'no-webgl2';
      } catch (e) {
        return 'error';
      }
    })(),
    bodyText: document.body.innerText.slice(0, 200),
  };
});

console.log('info:', JSON.stringify(info, null, 2));

const shot = `${outDir}/smoke.png`;
await page.screenshot({ path: shot });
console.log('captura:', shot);

console.log(`\nerrores (${errors.length}):`);
for (const e of errors) console.log('  ' + e);
console.log(`warnings (${warnings.length}):`);
for (const w of warnings.slice(0, 20)) console.log('  ' + w);

await browser.close();

if (!info.hasCanvas) {
  console.error('\nFALLO: no hay canvas');
  process.exit(1);
}
if (errors.length > 0) {
  console.error('\nFALLO: hay errores de consola');
  process.exit(2);
}
console.log('\nOK: el juego carga sin errores');
