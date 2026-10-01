// Prueba de UI del movil: abre el menu y comprueba que responde.
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
await page.waitForTimeout(11000);
await page.screenshot({ path: `${outDir}/ui_hud.png` });

// El juego de Godot dibuja todo en un canvas (no hay DOM), asi que
// pulsamos por coordenadas: boton MOVIL (arriba-derecha).
await page.mouse.click(1227, 83);
await page.waitForTimeout(900);
await page.screenshot({ path: `${outDir}/ui_phone.png` });

// Pulsar "Comprar placa" (primera opcion del panel) aprox.
await page.mouse.click(640, 250);
await page.waitForTimeout(800);
await page.screenshot({ path: `${outDir}/ui_phone_buy.png` });

console.log('capturas: ui_hud.png, ui_phone.png, ui_phone_buy.png');
console.log('errores:', errors.length);
for (const e of errors) console.log('  ' + e);
await browser.close();

