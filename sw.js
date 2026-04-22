// Wylde Self — Service Worker for Push Notifications

self.addEventListener('install', function(e) {
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(self.clients.claim());
});

// Handle incoming push notifications
self.addEventListener('push', function(e) {
  var data = { title: 'Wylde Self', body: 'Time to show up.', icon: '/Wyldeselflogo2.png', badge: '/Wyldeselflogo2.png', tag: 'wylde', url: '/' };

  if (e.data) {
    try {
      var payload = e.data.json();
      data.title = payload.title || data.title;
      data.body = payload.body || data.body;
      data.tag = payload.tag || data.tag;
      data.url = payload.url || data.url;
      if (payload.icon) data.icon = payload.icon;
    } catch (err) {
      data.body = e.data.text() || data.body;
    }
  }

  e.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: data.icon,
      badge: data.badge,
      tag: data.tag,
      renotify: true,
      data: { url: data.url },
      actions: [
        { action: 'open', title: 'Open' },
        { action: 'dismiss', title: 'Later' }
      ]
    })
  );
});

// Handle notification click
self.addEventListener('notificationclick', function(e) {
  e.notification.close();

  var url = (e.notification.data && e.notification.data.url) || '/';

  if (e.action === 'dismiss') return;

  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clients) {
      // Focus existing tab if open
      for (var i = 0; i < clients.length; i++) {
        if (clients[i].url.indexOf(self.location.origin) !== -1) {
          return clients[i].focus();
        }
      }
      // Otherwise open new tab
      return self.clients.openWindow(url);
    })
  );
});
