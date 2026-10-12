/* Resonance web service worker.
 * Caches the app shell (HTML, JS, CSS, fonts, icons) and cover images.
 * Never caches audio/video streams, API responses or sockets: the product
 * does not store third-party audio (see docs/ARCHITECTURE.md). */
const VERSION = "resonance-5.0.0";
const SHELL_CACHE = `${VERSION}-shell`;
const COVER_CACHE = `${VERSION}-covers`;
const COVER_LIMIT = 200;
const SHELL_URLS = ["/", "/index.html", "/offline.html", "/manifest.webmanifest", "/resonance.svg", "/icons/icon-192.png", "/icons/icon-512.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(SHELL_CACHE).then((cache) => cache.addAll(SHELL_URLS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => !key.startsWith(VERSION)).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("message", (event) => {
  if (event.data === "skip-waiting") self.skipWaiting();
});

function isMedia(request, url) {
  if (request.destination === "audio" || request.destination === "video" || request.destination === "track") return true;
  if (request.headers.has("range")) return true;
  return /\.(mp3|m4a|aac|ogg|opus|flac|wav|webm|mp4|m3u8|ts)(\?|$)/i.test(url.pathname);
}

function isBypassed(url) {
  return url.pathname.startsWith("/api/") || url.pathname.startsWith("/socket.io/") || url.pathname.startsWith("/downloads/");
}

async function trimCache(name, limit) {
  const cache = await caches.open(name);
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - limit; i += 1) await cache.delete(keys[i]);
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.protocol !== "http:" && url.protocol !== "https:") return;
  if (isMedia(request, url) || isBypassed(url)) return;

  // Navigations: network first, fall back to cached shell, then offline page.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok && url.origin === self.location.origin) {
            const copy = response.clone();
            caches.open(SHELL_CACHE).then((cache) => cache.put("/index.html", copy));
          }
          return response;
        })
        .catch(async () => (await caches.match("/index.html")) || (await caches.match("/offline.html")) || Response.error())
    );
    return;
  }

  // Cover art: cache first, any origin (opaque responses allowed), bounded.
  if (request.destination === "image") {
    event.respondWith(
      caches.open(COVER_CACHE).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cached;
        try {
          const response = await fetch(request);
          if (response.ok || response.type === "opaque") {
            cache.put(request, response.clone()).then(() => trimCache(COVER_CACHE, COVER_LIMIT));
          }
          return response;
        } catch {
          return cached || Response.error();
        }
      })
    );
    return;
  }

  // Same-origin static shell assets: stale-while-revalidate.
  if (url.origin === self.location.origin && ["script", "style", "font", "manifest"].includes(request.destination)) {
    event.respondWith(
      caches.open(SHELL_CACHE).then(async (cache) => {
        const cached = await cache.match(request);
        const network = fetch(request)
          .then((response) => {
            if (response.ok) cache.put(request, response.clone());
            return response;
          })
          .catch(() => cached);
        return cached || network;
      })
    );
  }
});
