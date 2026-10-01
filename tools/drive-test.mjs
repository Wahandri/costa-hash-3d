// Prueba de conduccion: entra en el vehiculo (ACCION) y acelera (W).
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
page.on('console', (m) => { console.log(`[console:${m.type()}] ${m.text()}`); if (m.type() === 'error') errors.push(m.text()); });

await page.goto(url, { waitUntil: 'load', timeout: 120000 });
await page.waitForTimeout(10000);
await page.screenshot({ path: `${outDir}/drive_before.png` });

await page.keyboard.press('e');          // ACCION -> entrar
await page.waitForTimeout(1200);
await page.screenshot({ path: `${outDir}/drive_entered.png` });

await page.keyboard.down('w');           // acelerar
await page.waitForTimeout(3500);
await page.keyboard.up('w');
await page.waitForTimeout(800);
await page.screenshot({ path: `${outDir}/drive_moving.png` });

await page.keyboard.press('e');          // ACCION -> salir
await page.waitForTimeout(800);
await page.screenshot({ path: `${outDir}/drive_exited.png` });

await browser.close();
console.log('capturas: drive_before/entered/moving/exited.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
