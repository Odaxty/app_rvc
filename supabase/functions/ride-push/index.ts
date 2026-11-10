import webPush from 'npm:web-push'
import { createClient } from 'npm:@supabase/supabase-js@2'

interface NotificationRecord {
  id: string
  recipient_id: string
  ride_id: string | null
  participant_name: string
  ride_name: string
  type: 'participant_joined' | 'ride_reminder' | 'ride_cancelled'
  start_location: string | null
  creator_name: string | null
}

interface PushSubscriptionRecord {
  id: string
  endpoint: string
  p256dh: string
  auth: string
}

const requiredEnv = (name: string) => {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

const supabaseUrl = requiredEnv('SUPABASE_URL')
const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY')
const dispatchSecret = requiredEnv('PUSH_DISPATCH_SECRET')
const vapidPublicKey = requiredEnv('VAPID_PUBLIC_KEY')
const vapidPrivateKey = requiredEnv('VAPID_PRIVATE_KEY')
const vapidSubject = requiredEnv('VAPID_SUBJECT')
const supabase = createClient(supabaseUrl, serviceRoleKey)

webPush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey)

Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  if (request.headers.get('x-push-dispatch-secret') !== dispatchSecret) {
    return new Response('Unauthorized', { status: 401 })
  }

  let notificationId: string
  try {
    const body: unknown = await request.json()
    if (
      typeof body !== 'object' ||
      body === null ||
      !('notification_id' in body) ||
      typeof body.notification_id !== 'string'
    ) {
      return new Response('Invalid notification payload', { status: 400 })
    }
    notificationId = body.notification_id
  } catch {
    return new Response('Invalid JSON payload', { status: 400 })
  }

  const { data: notification, error: notificationError } = await supabase
    .from('notifications')
    .select(
      'id, recipient_id, ride_id, participant_name, ride_name, type, start_location, creator_name',
    )
    .eq('id', notificationId)
    .maybeSingle<NotificationRecord>()

  if (notificationError) {
    console.error('Failed to load notification', notificationError)
    return new Response('Failed to load notification', { status: 500 })
  }
  if (!notification) return new Response('Notification no longer exists', { status: 204 })

  const { data: subscriptions, error: subscriptionsError } = await supabase
    .from('push_subscriptions')
    .select('id, endpoint, p256dh, auth')
    .eq('user_id', notification.recipient_id)

  if (subscriptionsError) {
    console.error('Failed to load push subscriptions', subscriptionsError)
    return new Response('Failed to load subscriptions', { status: 500 })
  }

  const { title, body } = getPushContent(notification)
  const url = notification.ride_id ? `ride/${notification.ride_id}` : './'
  const expiredSubscriptionIds: string[] = []
  const sendResults = await Promise.allSettled(
    ((subscriptions ?? []) as PushSubscriptionRecord[]).map(async (subscription) => {
      try {
        await webPush.sendNotification(
          {
            endpoint: subscription.endpoint,
            keys: { p256dh: subscription.p256dh, auth: subscription.auth },
          },
          JSON.stringify({ title, body, url, tag: notification.id }),
        )
      } catch (error) {
        const statusCode =
          typeof error === 'object' && error !== null && 'statusCode' in error
            ? error.statusCode
            : null
        if (statusCode === 404 || statusCode === 410) {
          expiredSubscriptionIds.push(subscription.id)
          return
        }
        throw error
      }
    }),
  )

  const sendErrors = sendResults.filter((result) => result.status === 'rejected')
  if (sendErrors.length) console.error('Some push notifications failed', sendErrors)

  if (expiredSubscriptionIds.length) {
    const { error } = await supabase
      .from('push_subscriptions')
      .delete()
      .in('id', expiredSubscriptionIds)
    if (error) {
      console.error('Failed to remove expired push subscriptions', error)
      return new Response('Failed to remove expired subscriptions', { status: 500 })
    }
  }

  if (sendErrors.length) return new Response('Some push notifications failed', { status: 502 })
  return new Response(null, { status: 204 })
})

function getPushContent(notification: NotificationRecord) {
  switch (notification.type) {
    case 'participant_joined':
      return {
        title: 'Nouvelle inscription',
        body: `${notification.participant_name} a rejoint « ${notification.ride_name} ».`,
      }
    case 'ride_reminder':
      return {
        title: 'Départ dans environ une heure',
        body: notification.start_location
          ? `« ${notification.ride_name} » — rendez-vous à ${notification.start_location}. Êtes-vous prêt(e) ?`
          : `« ${notification.ride_name} » commence bientôt. Êtes-vous prêt(e) ?`,
      }
    case 'ride_cancelled':
      return {
        title: 'Sortie annulée',
        body: `« ${notification.ride_name} », créée par ${notification.creator_name || 'son créateur'}, a été annulée. Découvrez les autres sorties.`,
      }
  }
}
