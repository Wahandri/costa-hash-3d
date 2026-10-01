// Prueba: tocar el boton MOVIL con input tactil y ver si abre el menu.
import { chromium } from 'playwright-core';
const url = process.argv[2] || 'http://localhost:3017/';
const outDir = process.argv[3] || new URL('./out/', import.meta.url).pathname;

const browser = await chromium.launch({
  executablePath: process.env.CHROME || '/usr/bin/google-chrome',
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader',
    '--use-gl=angle', '--use-angle=swiftshader'],
});
const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, hasTouch: true, isMobile: true });
const page = await context.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
await page.goto(url, { waitUntil: 'load', timeout: 120000 });
await page.waitForTimeout(10000);
const cdp = await context.newCDPSession(page);
const tap = async (x, y) => {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y, id: 1 }] });
  await page.waitForTimeout(60);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
};
await tap(1227, 83);           // boton MOVIL (arriba-derecha)
await page.waitForTimeout(900);
await page.screenshot({ path: `${outDir}/touch_movil.png` });
await browser.close();
console.log('captura: touch_movil.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
