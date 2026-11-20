/*
 * Pepinillo Web — offline shell service worker.
 * Strategy: precache the shell, then cache-first for same-origin static
 * assets and network-first for navigations with a cached fallback.
 * Navigations revalidate (cache: 'no-cache') so a deploy always reaches
 * the browser on the next visit — the fallback path below stays offline-only.
 * v2: also drops the accumulated v1 cache (old immutable chunks).
 */
const CACHE = 'pepinillo-shell-v2';
const SHELL = ['/', '/focus', '/manifest.webmanifest', '/favicon.svg'];

self.addEventListener('install', (event) => {
	event.waitUntil(
		caches
			.open(CACHE)
			.then((cache) => cache.addAll(SHELL))
			.then(() => self.skipWaiting())
	);
});

self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
			.then(() => self.clients.claim())
	);
});

self.addEventListener('fetch', (event) => {
	const { request } = event;
	if (request.method !== 'GET') return;

	const url = new URL(request.url);
	if (url.origin !== self.location.origin) return;

	// Navigations: network first with forced revalidation (fresh shell),
	// cached fallback when offline. 'no-cache' revalidates against the
	// server every time — HTTP-cached HTML would pin old chunk hashes (#974).
	if (request.mode === 'navigate') {
		event.respondWith(
			fetch(request, { cache: 'no-cache' })
				.then((response) => {
					const copy = response.clone();
					caches.open(CACHE).then((cache) => cache.put(request, copy));
					return response;
				})
				.catch(() => caches.match(request).then((hit) => hit ?? caches.match('/focus') ?? caches.match('/')))
		);
		return;
	}

	// Static assets: cache first.
	event.respondWith(
		caches.match(request).then(
			(hit) =>
				hit ??
				fetch(request).then((response) => {
					if (response.ok) {
						const copy = response.clone();
						caches.open(CACHE).then((cache) => cache.put(request, copy));
					}
					return response;
				})
		)
	);
});
