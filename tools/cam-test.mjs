// Prueba de camara conduciendo: orbita con raton y con touch (coche parado para
// que no actue el recentrado automatico).
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

await page.keyboard.press('e'); // entrar
await page.waitForTimeout(1200);
await page.screenshot({ path: `${outDir}/cam_enter.png` });

// 1) Raton (click para capturar + movimientos)
await page.mouse.click(640, 360);
for (let i = 0; i < 40; i++) { await page.mouse.move(640 - i * 18, 360); await page.waitForTimeout(12); }
await page.waitForTimeout(400);
await page.screenshot({ path: `${outDir}/cam_mouse.png` });

// 2) Touch (arrastre en la mitad derecha)
const cdp = await context.newCDPSession(page);
const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', {
  type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }],
});
await touch('touchStart', 1000, 380);
for (let i = 1; i <= 40; i++) { await touch('touchMove', 1000 - i * 16, 380); await page.waitForTimeout(12); }
await touch('touchEnd', 360, 380);
await page.waitForTimeout(400);
await page.screenshot({ path: `${outDir}/cam_touch.png` });

await browser.close();
console.log('capturas: cam_enter/cam_mouse/cam_touch.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
