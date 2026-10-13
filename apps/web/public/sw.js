/* Resonance web service worker.
 * Caches the app shell (HTML, hashed /assets/*, icons) and cover images.
 * Never caches audio/video streams, API responses or sockets: the product
 * does not store third-party audio (see docs/ARCHITECTURE.md).
 * __BUILD_ID__ is replaced with the build hash by the vite plugin in vite.config.ts. */
const VERSION = "resonance-__BUILD_ID__";
const SHELL_CACHE = `${VERSION}-shell`;
const ASSET_CACHE = `${VERSION}-assets`;
const COVER_CACHE = "resonance-covers";
const OPAQUE_CACHE = "resonance-covers-opaque";
const COVER_LIMIT = 200;
const OPAQUE_LIMIT = 25;
const SHELL_URLS = ["/", "/offline.html", "/manifest.webmanifest", "/resonance.svg", "/icons/icon-192.png", "/icons/icon-512.png"];
const KEEP = [SHELL_CACHE, ASSET_CACHE, COVER_CACHE, OPAQUE_CACHE];

self.addEventListener("install", (event) => {
  // No skipWaiting here: the page asks the user and sends "skip-waiting".
  event.waitUntil(caches.open(SHELL_CACHE).then((cache) => cache.addAll(SHELL_URLS)));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => !KEEP.includes(key)).map((key) => caches.delete(key))))
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

function isHtml(response) {
  return (response.headers.get("content-type") || "").includes("text/html");
}

/** SPA route: same origin, no file extension in the last path segment. */
function isSpaRoute(url) {
  return url.origin === self.location.origin && !/\.[a-z0-9]+$/i.test(url.pathname);
}

async function trimCache(name, limit) {
  const cache = await caches.open(name);
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - limit; i += 1) await cache.delete(keys[i]);
}

async function cacheFirst(cacheName, request) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) cache.put(request, response.clone());
  return response;
}

async function coverFirst(request) {
  const cached = (await caches.match(request, { cacheName: COVER_CACHE })) || (await caches.match(request, { cacheName: OPAQUE_CACHE }));
  if (cached) return cached;
  const response = await fetch(request);
  // ok/cors responses have a real size; opaque ones are padded by the browser
  // (several MB of quota each), so keep only a handful of them.
  if (response.ok && (response.type === "basic" || response.type === "cors")) {
    const cache = await caches.open(COVER_CACHE);
    cache.put(request, response.clone()).then(() => trimCache(COVER_CACHE, COVER_LIMIT));
  } else if (response.type === "opaque") {
    const cache = await caches.open(OPAQUE_CACHE);
    cache.put(request, response.clone()).then(() => trimCache(OPAQUE_CACHE, OPAQUE_LIMIT));
  }
  return response;
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.protocol !== "http:" && url.protocol !== "https:") return;
  if (isMedia(request, url) || isBypassed(url)) return;

  // Navigations: network first; only SPA HTML responses refresh the cached shell.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok && isSpaRoute(url) && isHtml(response)) {
            const copy = response.clone();
            caches.open(SHELL_CACHE).then((cache) => cache.put("/", copy));
          }
          return response;
        })
        .catch(async () =>
          (isSpaRoute(url) && (await caches.match("/", { cacheName: SHELL_CACHE }))) ||
          (await caches.match("/offline.html")) ||
          Response.error()
        )
    );
    return;
  }

  // Hashed build assets never change: cache first.
  if (url.origin === self.location.origin && url.pathname.startsWith("/assets/")) {
    event.respondWith(cacheFirst(ASSET_CACHE, request));
    return;
  }

  if (request.destination === "image") {
    event.respondWith(coverFirst(request).catch(() => Response.error()));
  }
});
