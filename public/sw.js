self.addEventListener('push', (event) => {
  if (!event.data) return

  const message = event.data.json()
  event.waitUntil(
    self.registration.showNotification(message.title, {
      body: message.body,
      icon: '/icon-192.png',
      badge: '/icon-192.png',
      tag: message.tag,
      data: { url: message.url },
    }),
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const targetUrl = new URL(event.notification.data?.url || './', self.registration.scope).href

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      const existingClient = clients.find((client) => client.url.startsWith(self.location.origin))
      if (existingClient) {
        return existingClient.navigate(targetUrl).then(() => existingClient.focus())
      }
      return self.clients.openWindow(targetUrl)
    }),
  )
})
