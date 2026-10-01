// Prueba anti-vuelco: acelera y gira fuerte a ambos lados.
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
await page.waitForTimeout(10000);
await page.keyboard.press('e');
await page.waitForTimeout(1200);

await page.keyboard.down('w');
await page.waitForTimeout(2000);
await page.keyboard.down('a');           // giro fuerte a la izquierda
await page.waitForTimeout(2500);
await page.keyboard.up('a');
await page.screenshot({ path: `${outDir}/turn_izq.png` });

await page.keyboard.down('d');           // giro fuerte a la derecha
await page.waitForTimeout(2500);
await page.keyboard.up('d');
await page.keyboard.up('w');
await page.screenshot({ path: `${outDir}/turn_der.png` });

await browser.close();
console.log('capturas: turn_izq/turn_der.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
