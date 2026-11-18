// Banebold 3D: lets the game be installed, and keeps a copy for when the network is slow or gone.
// Everything is fetched fresh first, so a new version is picked up at once; only the big engine file is kept.
const WASM = 'bb3d-wasm-v1', RT = 'bb3d-rt-v1';
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });
self.addEventListener('fetch', function (e) {
  var r = e.request;
  if (r.method !== 'GET') return;
  var u = new URL(r.url);
  if (u.origin !== location.origin) return;
  if (/\.wasm$/.test(u.pathname)) {
    e.respondWith(caches.open(WASM).then(function (c) {
      return c.match(r, { ignoreSearch: true }).then(function (hit) {
        var net = fetch(r).then(function (x) { if (x.ok) c.put(r, x.clone()); return x; });
        if (hit) { net.catch(function () {}); return hit; }
        return net;
      });
    }));
    return;
  }
  e.respondWith(fetch(r).then(function (x) {
    if (x.ok) { var cp = x.clone(); caches.open(RT).then(function (c) { c.put(r, cp); }); }
    return x;
  }).catch(function () { return caches.match(r, { ignoreSearch: true }); }));
});
