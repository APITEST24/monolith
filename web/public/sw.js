/* Monolith PWA. Caches the shell and, when the page is closed, tries to
   flush the offline queue with POST /api/v1/sync. iOS Safari has no
   Background Sync, so the page also flushes whenever it is open. */

const CACHE = "monolith-shell-v1";
const DB_NAME = "monolith";
const STORE = "kv";

const SHELL = [
  "/",
  "/index.html",
  "/manifest.webmanifest",
  "/demo-snapshot.json",
  "/icons/apple-touch-icon.png",
  "/splash/launch.png",
  "/fonts/Manrope-Regular.ttf",
  "/fonts/Manrope-Medium.ttf",
  "/fonts/Manrope-SemiBold.ttf",
  "/fonts/Manrope-Bold.ttf",
  "/fonts/Manrope-ExtraBold.ttf",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      await Promise.all(
        SHELL.map(async (url) => {
          try {
            await cache.add(url);
          } catch {
            /* a missing optional file must not block install */
          }
        }),
      );
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)));
      await self.clients.claim();
    })(),
  );
});

function isApi(pathname) {
  return (
    pathname.startsWith("/api/") ||
    pathname === "/health" ||
    pathname === "/docs" ||
    pathname.startsWith("/docs/") ||
    pathname === "/openapi.json" ||
    pathname === "/redoc"
  );
}

async function networkFirst(request) {
  const cache = await caches.open(CACHE);
  try {
    const fresh = await fetch(request);
    if (fresh.ok) cache.put(request, fresh.clone());
    return fresh;
  } catch {
    const cached = await cache.match(request);
    if (cached) return cached;
    if (request.mode === "navigate") {
      const shell = await cache.match("/index.html");
      if (shell) return shell;
    }
    throw new Error("offline");
  }
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);
  if (cached) return cached;
  const fresh = await fetch(request);
  if (fresh.ok) cache.put(request, fresh.clone());
  return fresh;
}

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  if (event.request.method !== "GET") return;
  if (isApi(url.pathname)) return;
  if (url.pathname === "/" || url.pathname === "/index.html") {
    event.respondWith(networkFirst(event.request));
    return;
  }
  event.respondWith(cacheFirst(event.request));
});

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(STORE)) req.result.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function idbGet(db, key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const req = tx.objectStore(STORE).get(key);
    req.onsuccess = () => resolve(req.result ?? null);
    req.onerror = () => reject(req.error);
  });
}

function idbSet(db, key, value) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).put(value, key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function flushQueue() {
  const db = await openDb();
  const queue = (await idbGet(db, "queue")) || [];
  const apiKey = await idbGet(db, "apiKey");
  if (!queue.length || !apiKey) return;
  const response = await fetch("/api/v1/sync", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": apiKey,
    },
    body: JSON.stringify({ mutations: queue }),
  });
  if (!response.ok) throw new Error("sync " + response.status);
  const body = await response.json();
  const applied = new Set(body.applied || []);
  const rejected = new Set((body.conflicts || []).map((item) => item.id));
  const next = queue.filter((item) => !applied.has(item.id) && !rejected.has(item.id));
  await idbSet(db, "queue", next);
  if (body.snapshot) await idbSet(db, "snapshot", body.snapshot);
  const clients = await self.clients.matchAll({ includeUncontrolled: true, type: "window" });
  for (const client of clients) {
    client.postMessage({ type: "synced", snapshot: body.snapshot, queue: next });
  }
}

self.addEventListener("sync", (event) => {
  if (event.tag === "monolith-sync") event.waitUntil(flushQueue());
});

self.addEventListener("message", (event) => {
  const data = event.data || {};
  if (data.type === "warm" && Array.isArray(data.urls)) {
    event.waitUntil(
      caches.open(CACHE).then((cache) =>
        Promise.all(
          data.urls.map(async (url) => {
            try {
              await cache.add(url);
            } catch {
              /* ignore */
            }
          }),
        ),
      ),
    );
  }
  if (data.type === "flush") event.waitUntil(flushQueue());
});

self.addEventListener("push", (event) => {
  let payload = { title: "Monolith", body: "" };
  try {
    if (event.data) payload = { ...payload, ...event.data.json() };
  } catch {
    if (event.data) payload.body = event.data.text();
  }
  event.waitUntil(
    self.registration.showNotification(payload.title || "Monolith", {
      body: payload.body || "",
      icon: "/icons/apple-touch-icon.png",
      badge: "/icons/apple-touch-icon.png",
      lang: "ru",
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if ("focus" in client) return client.focus();
      }
      return self.clients.openWindow("/");
    }),
  );
});
