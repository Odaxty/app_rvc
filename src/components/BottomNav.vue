<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { ArrowUpRight, Bell, Home, Map, Trash2, User, X } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { useAuth } from '../composables/useAuth'
import { getSupabaseClient } from '../supabase.ts'

const route = useRoute()
const router = useRouter()
const { user: authUser, initializeAuth } = useAuth()
const notifications = ref<
  Array<{
    id: string
    ride_id: string | null
    news_id: string | null
    participant_name: string
    ride_name: string
    message: string | null
    created_at: string
    read_at: string | null
    type:
      | 'participant_joined'
      | 'ride_reminder'
      | 'ride_cancelled'
      | 'comment_added'
      | 'ride_full'
      | 'news_published'
    start_location: string | null
    creator_name: string | null
  }>
>([])
const unreadCount = ref(0)
const isNotificationsOpen = ref(false)
const notificationError = ref('')
const notificationFilter = ref<'all' | 'unread' | 'read'>('all')
const visibleNotifications = computed(() =>
  notifications.value.filter((notification) => {
    if (notificationFilter.value === 'unread') return notification.read_at === null
    if (notificationFilter.value === 'read') return notification.read_at !== null
    return true
  }),
)
let notificationChannel: RealtimeChannel | null = null
let currentUserId: string | null = null

const loadNotifications = async () => {
  if (!currentUserId) return

  const supabase = getSupabaseClient()
  const [notificationsResult, unreadResult] = await Promise.all([
    supabase
      .from('notifications')
      .select(
        'id, ride_id, news_id, participant_name, ride_name, message, created_at, read_at, type, start_location, creator_name',
      )
      .order('created_at', { ascending: false })
      .limit(20),
    supabase.from('notifications').select('id', { count: 'exact', head: true }).is('read_at', null),
  ])

  if (notificationsResult.error || unreadResult.error) {
    notificationError.value = 'Impossible de charger les notifications.'
    return
  }

  notifications.value = notificationsResult.data
  unreadCount.value = unreadResult.count ?? 0
  notificationError.value = ''
}

const toggleNotifications = () => {
  isNotificationsOpen.value = !isNotificationsOpen.value
  if (isNotificationsOpen.value) void loadNotifications()
}

const openNotification = async (notification: (typeof notifications.value)[number]) => {
  if (!notification.read_at) {
    const readAt = new Date().toISOString()
    const { error } = await getSupabaseClient()
      .from('notifications')
      .update({ read_at: readAt })
      .eq('id', notification.id)

    if (error) {
      notificationError.value = 'Impossible de marquer cette notification comme lue.'
      return
    }

    notification.read_at = readAt
    unreadCount.value = Math.max(0, unreadCount.value - 1)
  }

  isNotificationsOpen.value = false
  if (notification.news_id) {
    await router.push({ name: 'news-detail', params: { id: notification.news_id } })
  } else if (notification.ride_id) {
    await router.push({ name: 'ride-detail', params: { id: notification.ride_id } })
  } else {
    await router.push('/')
  }
}

const deleteNotification = async (notification: (typeof notifications.value)[number]) => {
  const { error } = await getSupabaseClient()
    .from('notifications')
    .delete()
    .eq('id', notification.id)

  if (error) {
    notificationError.value = 'Impossible de supprimer cette notification.'
    return
  }

  notifications.value = notifications.value.filter((item) => item.id !== notification.id)
  if (!notification.read_at) unreadCount.value = Math.max(0, unreadCount.value - 1)
  notificationError.value = ''
}

const formatNotificationDate = (value: string) => {
  const elapsedMinutes = Math.floor((Date.now() - new Date(value).getTime()) / 60_000)
  if (elapsedMinutes < 1) return 'À l’instant'
  if (elapsedMinutes < 60) return `Il y a ${elapsedMinutes} min`

  const elapsedHours = Math.floor(elapsedMinutes / 60)
  if (elapsedHours < 24) return `Il y a ${elapsedHours} h`

  return new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' }).format(
    new Date(value),
  )
}

let stopWatchingUser: (() => void) | undefined

onMounted(async () => {
  try {
    await initializeAuth()
  } catch {
    notificationError.value = 'Impossible de vérifier la session utilisateur.'
    return
  }

  stopWatchingUser = watch(
    authUser,
    async (user) => {
      if (notificationChannel) {
        await getSupabaseClient().removeChannel(notificationChannel)
        notificationChannel = null
      }

      currentUserId = user?.id ?? null
      notifications.value = []
      unreadCount.value = 0
      isNotificationsOpen.value = false
      if (!currentUserId) return

      const userId = currentUserId
      await loadNotifications()
      notificationChannel = getSupabaseClient()
        .channel(`notifications:${userId}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'notifications',
            filter: `recipient_id=eq.${userId}`,
          },
          () => void loadNotifications(),
        )
        .subscribe((status) => {
          if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
            notificationError.value = 'Les notifications en temps réel sont indisponibles.'
          }
        })
    },
    { immediate: true },
  )
})

onBeforeUnmount(() => {
  stopWatchingUser?.()
  if (notificationChannel) void getSupabaseClient().removeChannel(notificationChannel)
})
</script>

<template>
  <section
    v-if="isNotificationsOpen"
    aria-labelledby="notifications-title"
    class="notification-panel fixed bottom-[7.5rem] left-1/2 z-[60] max-h-[min(65vh,34rem)] w-[min(26rem,calc(100vw-2rem))] -translate-x-1/2 overflow-hidden rounded-3xl border p-4 shadow-2xl sm:p-5"
  >
    <header class="mb-4 flex items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <span
          class="flex h-10 w-10 items-center justify-center rounded-2xl bg-emerald-500/15 text-emerald-500"
        >
          <Bell class="h-5 w-5" />
        </span>
        <div>
          <h2 id="notifications-title" class="font-bold">Notifications</h2>
          <p class="text-xs opacity-60">
            {{
              unreadCount
                ? `${unreadCount} non lue${unreadCount > 1 ? 's' : ''}`
                : 'Tout est à jour'
            }}
          </p>
        </div>
      </div>
      <button
        type="button"
        aria-label="Fermer les notifications"
        class="flex h-9 w-9 items-center justify-center rounded-xl opacity-60 transition hover:bg-black/5 hover:opacity-100"
        @click="isNotificationsOpen = false"
      >
        <X class="h-4 w-4" />
      </button>
    </header>

    <p
      v-if="notificationError"
      role="alert"
      class="rounded-2xl bg-red-500/10 p-3 text-sm text-red-600"
    >
      {{ notificationError }}
    </p>
    <div
      v-else-if="notifications.length"
      class="mb-3 grid grid-cols-3 gap-1 rounded-xl bg-black/5 p-1"
    >
      <button
        v-for="filter in [
          { value: 'all', label: 'Toutes' },
          { value: 'unread', label: 'Non lues' },
          { value: 'read', label: 'Lues' },
        ]"
        :key="filter.value"
        type="button"
        class="rounded-lg px-2 py-2 text-xs font-semibold transition"
        :class="
          notificationFilter === filter.value
            ? 'bg-emerald-600 text-white'
            : 'opacity-65 hover:bg-black/5 hover:opacity-100'
        "
        @click="notificationFilter = filter.value"
      >
        {{ filter.label }}
      </button>
    </div>
    <div
      v-if="!notificationError && notifications.length === 0"
      class="flex flex-col items-center rounded-2xl border border-dashed p-6 text-center"
    >
      <span
        class="mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-500"
      >
        <Bell class="h-5 w-5" />
      </span>
      <p class="text-sm font-semibold">Aucune notification</p>
      <p class="mt-1 text-xs opacity-60">Les nouvelles notifications apparaîtront ici.</p>
    </div>
    <p
      v-if="!notificationError && notifications.length && visibleNotifications.length === 0"
      class="rounded-2xl border border-dashed p-5 text-center text-sm opacity-60"
    >
      Aucune notification dans cette catégorie.
    </p>
    <ul
      v-if="!notificationError && visibleNotifications.length"
      class="max-h-[calc(min(65vh,34rem)-10rem)] space-y-2 overflow-y-auto pr-1"
    >
      <li
        v-for="notification in visibleNotifications"
        :key="notification.id"
        class="notification-item flex items-start gap-2 rounded-2xl border p-2"
        :class="notification.read_at ? 'is-read' : 'is-unread'"
      >
        <button
          type="button"
          class="flex min-w-0 flex-1 items-start gap-3 rounded-xl p-1 text-left"
          :aria-label="`Ouvrir la notification concernant ${notification.ride_name}`"
          @click="openNotification(notification)"
        >
          <span
            class="relative mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-emerald-500/15 text-sm font-bold text-emerald-600"
          >
            {{ notification.participant_name.charAt(0).toLocaleUpperCase() }}
            <span
              v-if="!notification.read_at"
              class="absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full border-2 border-[var(--notification-panel-bg)] bg-emerald-500"
            />
          </span>
          <span class="min-w-0 flex-1">
            <span v-if="notification.type === 'participant_joined'" class="block text-sm leading-5">
              <strong>{{ notification.participant_name }}</strong>
              a rejoint votre sortie
            </span>
            <span v-else-if="notification.type === 'comment_added'" class="block text-sm leading-5">
              <strong>{{ notification.participant_name }}</strong>
              a envoyé un message sur cette sortie
            </span>
            <span v-else-if="notification.type === 'ride_reminder'" class="block text-sm leading-5">
              Votre sortie commence dans environ une heure.
            </span>
            <span
              v-else-if="notification.type === 'ride_cancelled'"
              class="block text-sm leading-5"
            >
              {{
                notification.message ||
                `La sortie a été annulée par ${notification.creator_name || 'son créateur'}.`
              }}
            </span>
            <span v-else-if="notification.type === 'ride_full'" class="block text-sm leading-5">
              Cette sortie est complète.
            </span>
            <span v-else class="block text-sm leading-5">Nouvelle actualité</span>
            <span class="mt-0.5 block truncate text-sm font-bold">
              {{ notification.ride_name }}
            </span>
            <span
              v-if="notification.type === 'comment_added' && notification.message"
              class="mt-0.5 block whitespace-pre-line text-xs opacity-70"
            >
              {{ notification.message }}
            </span>
            <span
              v-else-if="notification.type === 'news_published' && notification.message"
              class="mt-0.5 block whitespace-pre-line text-xs opacity-70"
            >
              {{ notification.message }}
            </span>
            <span
              v-if="notification.type === 'ride_reminder' && notification.start_location"
              class="mt-0.5 block truncate text-xs opacity-70"
            >
              Départ : {{ notification.start_location }} · Êtes-vous prêt(e) ?
            </span>
            <span
              v-else-if="notification.type === 'ride_reminder'"
              class="mt-0.5 block text-xs opacity-70"
            >
              Départ à confirmer · Êtes-vous prêt(e) ?
            </span>
            <span
              v-else-if="notification.type === 'ride_cancelled'"
              class="mt-0.5 block text-xs opacity-70"
            >
              Inscrivez-vous à une autre sortie.
            </span>
            <span class="mt-1 block text-xs opacity-55">
              {{ formatNotificationDate(notification.created_at) }}
            </span>
          </span>
          <ArrowUpRight class="mt-1 h-4 w-4 shrink-0 opacity-40" />
        </button>
        <button
          type="button"
          :aria-label="`Supprimer la notification concernant ${notification.ride_name}`"
          title="Supprimer la notification"
          class="mt-1 flex h-9 w-9 shrink-0 items-center justify-center rounded-xl opacity-55 transition hover:bg-red-500/10 hover:text-red-600 hover:opacity-100"
          @click="deleteNotification(notification)"
        >
          <Trash2 class="h-4 w-4" />
        </button>
      </li>
    </ul>
  </section>

  <nav class="glass-nav fixed bottom-0 left-0 right-0 z-50">
    <div class="mx-auto flex h-16 max-w-xl items-center justify-around">
      <router-link
        to="/gpx"
        aria-label="Parcours GPX"
        class="bottom-nav-link"
        :class="{ 'is-active': route.name === 'gpx' }"
      >
        <Map class="h-5 w-5" />
        <span>Parcours</span>
      </router-link>

      <router-link
        to="/"
        aria-label="Accueil, sorties"
        class="bottom-nav-link"
        :class="{ 'is-active': route.name === 'home' }"
      >
        <Home class="h-5 w-5" />
        <span>Sorties</span>
      </router-link>

      <button
        v-if="currentUserId"
        type="button"
        aria-label="Notifications"
        :aria-expanded="isNotificationsOpen"
        class="bottom-nav-link relative"
        :class="{ 'is-active': isNotificationsOpen }"
        @click="toggleNotifications"
      >
        <Bell class="h-5 w-5" />
        <span>Notifications</span>
        <span
          v-if="unreadCount"
          class="absolute right-1/2 top-0 flex h-4 min-w-4 translate-x-5 items-center justify-center rounded-full bg-red-600 px-1 text-[10px] font-bold text-white"
        >
          {{ unreadCount > 9 ? '9+' : unreadCount }}
        </span>
      </button>

      <router-link
        to="/profile"
        aria-label="Mon profil"
        class="bottom-nav-link"
        :class="{ 'is-active': route.name === 'profile' }"
      >
        <User class="h-5 w-5" />
        <span>Mon compte</span>
      </router-link>
    </div>
    <p class="bottom-nav-credit pb-2 text-center text-[11px]">
      Réalisé par
      <a
        href="https://theo.chauviere.eu/"
        target="_blank"
        rel="noopener noreferrer"
        class="bottom-nav-credit-link font-semibold underline-offset-2 hover:underline"
      >
        DevWebTheo
      </a>
    </p>
  </nav>
</template>
