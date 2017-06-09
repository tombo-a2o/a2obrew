let params;

self.addEventListener('install', (event) => {
  event.waitUntil(
    fetch('runtime_parameters.json', {
      credentials: 'same-origin'
    }).then((response) => {
      return response.json();
    }).then((json) => {
      params = json.A2OShell;
      return caches.open(params.serviceWorkerCacheName);
    }).then((cache) => {
      return cache.addAll(params.pathsToCache);
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      if (response) {
        console.log(`Fetch from cache: ${response.url}`);
        return response;
      }
      return fetch(event.request);
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (params.serviceWorkerCacheName !== cacheName) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});
