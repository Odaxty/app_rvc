<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Calendar, Clock, Download, MapPin } from 'lucide-vue-next'
import RideGpxMap from '../components/RideGpxMap.vue'
import { getSupabaseClient } from '../supabase.ts'

interface Ride {
  name: string
  description: string | null
  gpx_id: string | null
  max_participants: number | null
  date: string
  time: string
  distance: number
  bike_type: string | null
  ride_type: string | null
  start_location: string | null
  difficulty: number | null
  image_url: string | null
}

interface Participant {
  id: string
  name: string
  initials: string
  avatarUrl: string | null
}

interface RideComment {
  id: string
  author: string
  createdAt: string
  message: string
}

const route = useRoute()
const router = useRouter()
const ride = ref<Ride | null>(null)
const gpxFileUrl = ref<string | null>(null)
const hasSession = ref(false)
const isLoading = ref(true)
const errorMessage = ref('')
const participantCount = ref(0)
const participants = ref<Participant[]>([])
const isJoined = ref(false)
const isLoadingParticipants = ref(true)
const participantsError = ref('')
const isJoining = ref(false)
const joinError = ref('')
const isRideFull = computed(
  () =>
    ride.value?.max_participants != null && participantCount.value >= ride.value.max_participants,
)
const isDownloadingGpx = ref(false)
const downloadError = ref('')
const comments = ref<RideComment[]>([])
const isLoadingComments = ref(true)
const commentsError = ref('')
const commentText = ref('')
const isSendingComment = ref(false)
const sendCommentError = ref('')
const difficultyLabels: Record<number, string> = {
  1: 'Découverte',
  2: 'Modéré',
  3: 'Sportif',
  4: 'Compétition',
}

const fetchComments = async (rideId: string) => {
  isLoadingComments.value = true
  commentsError.value = ''

  try {
    const supabase = getSupabaseClient()
    const { data, error } = await supabase
      .from('comments')
      .select('id, user_id, message, created_at')
      .eq('ride_id', rideId)
      .order('created_at', { ascending: true })

    if (error) throw error
    if (data.length === 0) {
      comments.value = []
      return
    }

    const userIds = [...new Set(data.map((comment) => comment.user_id))]
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, firstname, lastname, avatar_url')
      .in('id', userIds)

    if (usersError) throw usersError

    const userNames = new Map(
      (users ?? []).map((user) => [user.id, `${user.firstname} ${user.lastname}`]),
    )
    comments.value = data.map((comment) => ({
      id: comment.id,
      author: userNames.get(comment.user_id) ?? 'Membre',
      createdAt: comment.created_at,
      message: comment.message,
    }))
  } catch (error) {
    commentsError.value =
      error instanceof Error ? error.message : 'Impossible de charger les messages.'
  } finally {
    isLoadingComments.value = false
  }
}

const fetchParticipants = async (rideId: string) => {
  isLoadingParticipants.value = true
  participantsError.value = ''

  try {
    const supabase = getSupabaseClient()
    const {
      data: { session },
    } = await supabase.auth.getSession()
    const { data, error } = await supabase
      .from('ride_participants')
      .select('user_id')
      .eq('ride_id', rideId)

    if (error) throw error

    participantCount.value = data.length
    isJoined.value = session
      ? data.some((participant) => participant.user_id === session.user.id)
      : false

    if (data.length === 0) {
      participants.value = []
      return
    }

    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, firstname, lastname, avatar_url')
      .in(
        'id',
        data.map((participant) => participant.user_id),
      )

    if (usersError) throw usersError
    participants.value = (users ?? []).map((user) => ({
      id: user.id,
      name: `${user.firstname} ${user.lastname}`,
      initials: `${user.firstname.charAt(0)}${user.lastname.charAt(0)}`.toUpperCase(),
      avatarUrl: user.avatar_url,
    }))
  } catch (error) {
    participantsError.value =
      error instanceof Error ? error.message : 'Impossible de charger les participants.'
  } finally {
    isLoadingParticipants.value = false
  }
}

watch(
  () => route.params.id,
  async (id) => {
    if (typeof id !== 'string') return

    isLoading.value = true
    errorMessage.value = ''

    try {
      const supabase = getSupabaseClient()
      const { data, error } = await supabase
        .from('rides')
        .select(
          'name, description, gpx_id, max_participants, date, time, distance, bike_type, ride_type, start_location, difficulty, image_url',
        )
        .eq('id', id)
        .single()

      if (error) throw error
      ride.value = data
      gpxFileUrl.value = null
      const {
        data: { session },
        error: sessionError,
      } = await supabase.auth.getSession()
      if (sessionError) throw sessionError
      hasSession.value = Boolean(session)

      if (data.gpx_id && session) {
        const { data: gpxTrack, error: gpxError } = await supabase
          .from('gpx_tracks')
          .select('file_url')
          .eq('id', data.gpx_id)
          .single()

        if (gpxError) throw gpxError
        gpxFileUrl.value = gpxTrack.file_url
      }
      void fetchParticipants(id)
      void fetchComments(id)
    } catch (error) {
      errorMessage.value =
        error instanceof Error ? error.message : 'Impossible de charger cette sortie.'
    } finally {
      isLoading.value = false
    }
  },
  { immediate: true },
)

const handleJoin = async () => {
  isJoining.value = true
  joinError.value = ''

  try {
    const supabase = getSupabaseClient()
    const {
      data: { session },
      error: sessionError,
    } = await supabase.auth.getSession()

    if (sessionError) throw sessionError
    if (!session) {
      await router.push('/auth')
      return
    }

    const rideId = route.params.id
    if (typeof rideId !== 'string') throw new Error('Identifiant de sortie invalide.')

    if (ride.value?.max_participants != null) {
      const { count, error: countError } = await supabase
        .from('ride_participants')
        .select('user_id', { count: 'exact', head: true })
        .eq('ride_id', rideId)

      if (countError) throw countError
      if ((count ?? 0) >= ride.value.max_participants) {
        participantCount.value = count ?? 0
        throw new Error('Cette sortie est complète.')
      }
    }

    const { error } = await supabase.from('ride_participants').insert({
      ride_id: rideId,
      user_id: session.user.id,
    })

    if (error?.code === 'P0001' && error.message.includes('ride_full')) {
      await fetchParticipants(rideId)
      throw new Error('Cette sortie vient d’être complète. Il n’y a plus de places disponibles.')
    }
    if (error && error.code !== '23505') throw error

    isJoined.value = true
    await fetchParticipants(rideId)
  } catch (error) {
    joinError.value =
      error instanceof Error ? error.message : 'Impossible de rejoindre cette sortie.'
  } finally {
    isJoining.value = false
  }
}

const downloadGpx = async () => {
  if (!isJoined.value) {
    await router.push('/auth')
    return
  }
  if (!gpxFileUrl.value || !ride.value) return

  isDownloadingGpx.value = true
  downloadError.value = ''

  try {
    const response = await fetch(gpxFileUrl.value)
    if (!response.ok) throw new Error('Impossible de télécharger ce parcours GPX.')

    const objectUrl = URL.createObjectURL(await response.blob())
    const link = document.createElement('a')
    link.href = objectUrl
    link.download = `${ride.value.name.replace(/[^a-z0-9]+/gi, '-')}.gpx`
    document.body.append(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(objectUrl)
  } catch (error) {
    downloadError.value =
      error instanceof Error ? error.message : 'Impossible de télécharger le GPX.'
  } finally {
    isDownloadingGpx.value = false
  }
}

const sendComment = async () => {
  const message = commentText.value.trim()
  const rideId = route.params.id

  if (!message || typeof rideId !== 'string') return
  if (!isJoined.value) {
    sendCommentError.value = 'Rejoins cette sortie pour participer à la discussion.'
    return
  }

  isSendingComment.value = true
  sendCommentError.value = ''

  try {
    const supabase = getSupabaseClient()
    const {
      data: { session },
      error: sessionError,
    } = await supabase.auth.getSession()

    if (sessionError) throw sessionError
    if (!session) {
      await router.push('/auth')
      return
    }

    const { error } = await supabase.from('comments').insert({
      ride_id: rideId,
      user_id: session.user.id,
      message,
    })

    if (error) throw error

    commentText.value = ''
    await fetchComments(rideId)
  } catch (error) {
    sendCommentError.value =
      error instanceof Error ? error.message : 'Impossible d’envoyer le message.'
  } finally {
    isSendingComment.value = false
  }
}

const formatCommentDate = (createdAt: string) =>
  new Date(createdAt).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })

const formatRideDate = (date: string) =>
  new Date(`${date}T00:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })
</script>

<template>
  <!-- Padding bottom important pour ne pas être caché par la BottomNav -->
  <div class="app-page min-h-screen bg-gray-50 pt-6 px-4 pb-24">
    <!-- En-tête -->
    <div class="flex items-center gap-4 mb-6">
      <button @click="router.back()" class="p-1 hover:bg-gray-200 rounded-full transition-colors">
        <ArrowLeft class="w-7 h-7 text-black" stroke-width="2.5" />
      </button>
      <h1 class="app-page-title text-2xl font-bold text-white">Détail de la sortie</h1>
    </div>

    <p v-if="isLoading" class="py-8 text-center text-sm text-gray-500">
      Chargement de la sortie...
    </p>
    <p v-else-if="errorMessage" role="alert" class="rounded-xl bg-red-50 p-3 text-sm text-red-700">
      {{ errorMessage }}
    </p>

    <template v-else-if="ride">
      <!-- Espace Carte (Map View) -->
      <div
        v-if="ride.image_url"
        class="relative mb-6 aspect-video w-full overflow-hidden rounded-3xl border border-gray-100 bg-gray-200"
      >
        <img
          :src="ride.image_url"
          :alt="`Image de la sortie ${ride.name}`"
          class="h-full w-full object-cover"
        />
      </div>
      <RideGpxMap v-else-if="gpxFileUrl" :file-url="gpxFileUrl" />
      <div
        v-else
        class="relative mb-6 aspect-video w-full overflow-hidden rounded-3xl border border-gray-100 bg-gray-200"
      >
        <span class="flex h-full items-center justify-center p-4 font-semibold text-gray-400">
          Aucune image disponible
        </span>
      </div>
      <RideGpxMap v-if="ride.image_url && gpxFileUrl" :file-url="gpxFileUrl" />
      <p
        v-if="ride.gpx_id && !hasSession"
        class="mb-6 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-white/70"
      >
        Connecte-toi pour consulter le tracé GPX de cette sortie.
      </p>

      <!-- Informations de la sortie -->
      <div class="mb-8">
        <div class="flex justify-between items-start mb-1">
          <h2 class="text-2xl font-bold text-white">{{ ride.name }}</h2>
          <span
            v-if="ride.bike_type"
            class="bg-green-100 text-green-700 px-3 py-1 rounded-full text-sm font-semibold"
          >
            {{ ride.bike_type }}
          </span>
          <span
            v-if="ride.ride_type"
            class="rounded-full px-3 py-1 text-sm font-semibold"
            :class="
              ride.ride_type === 'Club' ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-700'
            "
          >
            {{ ride.ride_type }}
          </span>
        </div>
        <p v-if="ride.description" class="text-gray-500 text-sm mb-5">{{ ride.description }}</p>

        <p v-if="ride.start_location" class="mb-4 flex items-start gap-2 text-sm text-gray-600">
          <MapPin class="mt-0.5 h-4 w-4 shrink-0 text-green-600" />
          <span>{{ ride.start_location }}</span>
        </p>

        <!-- Badges (Date, Heure, Distance) -->
        <div class="flex flex-wrap gap-3">
          <div
            class="surface-card flex items-center gap-2 bg-white border border-gray-100 px-4 py-2.5 rounded-2xl shadow-sm"
          >
            <Calendar class="w-4 h-4 text-red-500" />
            <span class="font-bold text-gray-900 text-sm">{{ formatRideDate(ride.date) }}</span>
          </div>
          <div
            class="surface-card flex items-center gap-2 bg-white border border-gray-100 px-4 py-2.5 rounded-2xl shadow-sm"
          >
            <Clock class="w-4 h-4 text-red-500" />
            <span class="font-bold text-gray-900 text-sm">{{ ride.time.slice(0, 5) }}</span>
          </div>
          <div
            class="surface-card flex items-center gap-2 bg-white border border-gray-100 px-4 py-2.5 rounded-2xl shadow-sm"
          >
            <MapPin class="w-4 h-4 text-green-500" />
            <span class="font-bold text-gray-900 text-sm">{{ ride.distance }} km</span>
          </div>
          <span
            v-if="ride.difficulty"
            class="surface-card flex items-center rounded-2xl border border-gray-100 bg-white px-4 py-2.5 text-sm font-bold text-gray-800 shadow-sm"
          >
            {{ ride.difficulty }} vélo{{ ride.difficulty > 1 ? 's' : '' }} ·
            {{ difficultyLabels[ride.difficulty] }}
          </span>
        </div>
      </div>

      <div class="mb-6">
        <button
          type="button"
          @click="handleJoin"
          :disabled="isJoining || isJoined || isRideFull || isLoadingParticipants"
          class="w-full bg-green-500 text-white font-bold py-3.5 rounded-xl hover:bg-green-600 transition-colors disabled:cursor-not-allowed disabled:opacity-60"
        >
          {{
            isJoining
              ? 'Inscription...'
              : isJoined
                ? 'Déjà inscrit'
                : isRideFull
                  ? 'Sortie complète'
                  : 'Rejoindre la sortie'
          }}
        </button>
        <p v-if="joinError" role="alert" class="mt-2 text-sm text-red-700">{{ joinError }}</p>
      </div>

      <div v-if="gpxFileUrl && isJoined" class="mb-6">
        <button
          type="button"
          :disabled="isDownloadingGpx"
          class="flex w-full items-center justify-center gap-2 rounded-xl bg-gray-900 py-3 font-semibold text-white transition-colors hover:bg-black disabled:opacity-50"
          @click="downloadGpx"
        >
          <Download class="h-5 w-5" />
          {{ isDownloadingGpx ? 'Téléchargement...' : 'Télécharger le GPX' }}
        </button>
        <p v-if="downloadError" role="alert" class="mt-2 text-sm text-red-700">
          {{ downloadError }}
        </p>
      </div>

      <!-- Participants -->
      <div class="surface-card bg-white p-5 rounded-3xl shadow-sm mb-6 border border-gray-50">
        <h3 class="font-bold text-lg text-gray-900">
          Participants ({{ participantCount
          }}<template v-if="ride.max_participants !== null"> / {{ ride.max_participants }}</template
          >)
        </h3>
        <p v-if="isLoadingParticipants" class="mt-2 text-sm text-gray-500">
          Chargement des participants...
        </p>
        <p v-else-if="participantsError" role="alert" class="mt-2 text-sm text-red-700">
          {{ participantsError }}
        </p>
        <p v-else-if="participantCount === 0" class="mt-2 text-sm text-gray-500">
          Aucun participant inscrit pour le moment.
        </p>
        <p v-else-if="isJoined" class="mt-2 text-sm text-green-700">
          Vous êtes inscrit à cette sortie.
        </p>
        <ul v-if="participants.length" class="mt-4 space-y-3">
          <li
            v-for="participant in participants"
            :key="participant.id"
            class="flex items-center gap-3"
          >
            <img
              v-if="participant.avatarUrl"
              :src="participant.avatarUrl"
              :alt="`Photo de ${participant.name}`"
              class="h-10 w-10 rounded-full object-cover"
            />
            <span
              v-else
              class="flex h-10 w-10 items-center justify-center rounded-full bg-green-100 font-bold text-green-800"
              >{{ participant.initials }}</span
            >
            <span class="text-sm font-medium text-gray-800">{{ participant.name }}</span>
          </li>
        </ul>
      </div>

      <!-- Discussions -->
      <div class="mb-4">
        <h3 class="mb-4 text-lg font-bold text-white">Discussions</h3>
        <p v-if="isLoadingComments" class="py-4 text-sm text-gray-500">
          Chargement des messages...
        </p>
        <p v-else-if="commentsError" role="alert" class="mb-3 text-sm text-red-700">
          {{ commentsError }}
        </p>
        <p v-else-if="comments.length === 0" class="mb-3 text-sm text-gray-500">
          Aucun message pour le moment.
        </p>

        <div v-else class="space-y-3">
          <article
            v-for="comment in comments"
            :key="comment.id"
            class="surface-card rounded-2xl border border-gray-100 bg-white p-4 shadow-sm"
          >
            <div class="mb-2 flex items-baseline justify-between gap-3">
              <span class="font-bold text-gray-900">{{ comment.author }}</span>
              <time class="shrink-0 text-xs text-gray-500">{{
                formatCommentDate(comment.createdAt)
              }}</time>
            </div>
            <p class="whitespace-pre-wrap text-sm leading-relaxed text-gray-700">
              {{ comment.message }}
            </p>
          </article>
        </div>

        <form v-if="isJoined" class="mt-4 space-y-3" @submit.prevent="sendComment">
          <label for="ride-comment" class="sr-only">Ton message</label>
          <textarea
            id="ride-comment"
            v-model="commentText"
            required
            maxlength="1000"
            rows="3"
            placeholder="Écrire un message..."
            class="comment-input w-full resize-y rounded-xl border border-gray-200 bg-white px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-red-500"
          />
          <p v-if="sendCommentError" role="alert" class="text-sm text-red-700">
            {{ sendCommentError }}
          </p>
          <button
            type="submit"
            :disabled="isSendingComment || !commentText.trim()"
            class="w-full rounded-xl bg-green-600 py-3 font-semibold text-white transition-colors hover:bg-green-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {{ isSendingComment ? 'Envoi...' : 'Envoyer le message' }}
          </button>
        </form>
        <p v-else class="mt-4 text-sm text-gray-500">
          Rejoins cette sortie pour participer à la discussion.
        </p>
      </div>
    </template>
  </div>
</template>
