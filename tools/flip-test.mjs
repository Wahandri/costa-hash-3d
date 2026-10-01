// Test de vuelco: slalom fuerte + giros cerrados + acelerar a fondo.
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
await page.keyboard.press('e');            // subir al vehiculo
await page.waitForTimeout(1200);

await page.keyboard.down('w');
await page.keyboard.down('Shift');         // a fondo
for (let i = 0; i < 6; i++) {              // slalom
  await page.keyboard.down('a');
  await page.waitForTimeout(1100);
  await page.keyboard.up('a');
  await page.keyboard.down('d');
  await page.waitForTimeout(1100);
  await page.keyboard.up('d');
  await page.screenshot({ path: `${outDir}/flip_${i}.png` });
}
await page.keyboard.up('Shift');
await page.keyboard.up('w');
await page.waitForTimeout(800);
await page.screenshot({ path: `${outDir}/flip_final.png` });

await browser.close();
console.log('capturas: flip_0..5 + flip_final');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
