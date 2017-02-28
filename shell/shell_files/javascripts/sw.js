let params;

self.addEventListener('install', (event) => {
  event.waitUntil(
    fetch('../../runtime_parameters.json').then((response) => {
      return response.json();
    }).then((json) => {
      params = json.A2OShell;
      return caches.open(params.serviceWorkerCacheName);
    }).then((cache) => {
      return cache.addAll(params.pathsToCache.map((path) => {
        return `../../${path}`;
      }));
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      if (response) { return response; }
      let fetchRequest = event.request.clone();

      return fetch(fetchRequest).then((response) => {
        if (!response || response.status !== 200 || response.type !== 'basic') {
          return response;
        }
        let responseToCache = response.clone();

        caches.open(params.serviceWorkerCacheName).then((cache) => {
          cache.put(event.request, responseToCache);
        })

        return response;
      });
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
