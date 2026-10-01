// Prueba visual: comete delitos, sube la busqueda y captura la persecucion.
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

for (let i = 0; i < 3; i++) {
  await page.keyboard.press('r');
  await page.waitForTimeout(900);
}
await page.screenshot({ path: `${outDir}/police_wanted.png` });

// Girar la camara (click + arrastre) para buscar la poli
await page.mouse.click(640, 360);
for (let step = 0; step < 3; step++) {
  for (let i = 0; i < 15; i++) {
    await page.mouse.move(640 + i * 14, 360);
    await page.waitForTimeout(30);
  }
  await page.waitForTimeout(2500);
  await page.screenshot({ path: `${outDir}/police_${step}.png` });
}

await browser.close();
console.log('capturas: police_wanted.png, police_0/1/2.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
