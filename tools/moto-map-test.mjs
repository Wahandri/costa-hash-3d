// Prueba: moto inicial, entrada, mapa (M) y noche (N x2).
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
await page.screenshot({ path: `${outDir}/moto_inicio.png` });

await page.keyboard.press('m');
await page.waitForTimeout(800);
await page.screenshot({ path: `${outDir}/mapa.png` });
await page.keyboard.press('m');
await page.waitForTimeout(400);

await page.keyboard.press('e'); // entrar a la moto
await page.waitForTimeout(1000);
await page.keyboard.down('w');
await page.waitForTimeout(2500);
await page.keyboard.up('w');
await page.waitForTimeout(600);
await page.screenshot({ path: `${outDir}/moto_drive.png` });

await page.keyboard.press('e'); // bajarse
await page.waitForTimeout(600);
await page.keyboard.press('n'); // +6h
await page.waitForTimeout(600);
await page.keyboard.press('n'); // +6h -> noche
await page.waitForTimeout(1500);
await page.screenshot({ path: `${outDir}/noche.png` });

await browser.close();
console.log('capturas: moto_inicio/mapa/moto_drive/noche.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
