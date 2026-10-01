// Verifica que el jugador se mueve con el teclado (captura antes/despues).
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
await page.goto(url, { waitUntil: 'load', timeout: 120000 });
await page.waitForTimeout(10000);
await page.screenshot({ path: `${outDir}/move_before.png` });

await page.keyboard.down('w');
await page.waitForTimeout(2500);
await page.keyboard.up('w');
await page.waitForTimeout(500);
await page.screenshot({ path: `${outDir}/move_after.png` });

// Captura de raton (click) y giro de camara
await page.mouse.click(640, 360);
await page.waitForTimeout(300);
for (let i = 0; i < 20; i++) {
  await page.mouse.move(640 + i * 12, 360);
  await page.waitForTimeout(30);
}
await page.waitForTimeout(300);
await page.screenshot({ path: `${outDir}/move_turn.png` });

await browser.close();
console.log('capturas: move_before.png, move_after.png, move_turn.png');
