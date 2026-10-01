// Service Worker minimo (network-first): habilita la instalacion como app (PWA)
// y sirve de cache de respaldo si no hay red. No cachea el build (pck/wasm se
// revalidan siempre), para no servir versiones viejas.
const CACHE = 'costa3d-shell-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});
