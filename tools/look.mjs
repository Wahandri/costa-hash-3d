// Captura el jugador desde varios angulos para revisar modelos/orientacion.
import { chromium } from 'playwright-core';

const url = process.argv[2] || 'http://localhost:3017/';
const outDir = process.argv[3] || new URL('./out/', import.meta.url).pathname;

const browser = await chromium.launch({
  executablePath: process.env.CHROME || '/usr/bin/google-chrome',
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader',
    '--use-gl=angle', '--use-angle=swiftshader'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

await page.goto(url, { waitUntil: 'load', timeout: 120000 });
await page.waitForTimeout(9000);
await page.screenshot({ path: `${outDir}/look_back.png` });

// Arrastrar para orbitar la camara
await page.mouse.move(640, 360);
await page.mouse.down();
for (let i = 0; i < 60; i++) { await page.mouse.move(640 - i * 6, 360); await page.waitForTimeout(15); }
await page.mouse.up();
await page.waitForTimeout(1500);
await page.screenshot({ path: `${outDir}/look_side.png` });

for (let i = 0; i < 60; i++) { await page.mouse.move(640, 360); await page.mouse.move(640 - i * 9, 360); await page.waitForTimeout(15); }
await page.waitForTimeout(1500);
await page.screenshot({ path: `${outDir}/look_front.png` });

await browser.close();
console.log('capturas: look_back/look_side/look_front.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
