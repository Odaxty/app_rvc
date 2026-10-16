<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import {
  Activity,
  ArrowRight,
  Bike,
  CalendarDays,
  ChevronDown,
  Clock3,
  Image as ImageIcon,
  MapPin,
  Newspaper,
  Plus,
  Search,
  SlidersHorizontal,
  UserRound,
} from 'lucide-vue-next'
import GpxTracePreview from '../components/GpxTracePreview.vue'
import { getSupabaseClient } from '../supabase.ts'
import { useAuth } from '../composables/useAuth'

interface Ride {
  id: string
  name: string
  date: string
  time: string
  distance: number
  bike_type: string | null
  ride_type: string | null
  start_location: string | null
  difficulty: number | null
  image_url: string | null
  gpx_id: string | null
  gpx_file_url: string | null
}

interface NewsBannerItem {
  id: string
  title: string
  summary: string | null
  category: string
  bike_type: string | null
  image_url: string | null
  created_at: string
}

interface BannerCardItem {
  key: string
  type: 'news' | 'ride'
  title: string
  subtitle: string
  badge: string
  bikeType: string | null
  dateLabel: string
  imageUrl: string | null
  gpxFileUrl: string | null
  linkTo: string | { name: string; params: { id: string } }
  linkLabel: string
}

const rides = ref<Ride[]>([])
const latestNews = ref<NewsBannerItem[]>([])
const searchTerm = ref('')
const minDistance = ref<number | null>(null)
const maxDistance = ref<number | null>(null)
const selectedBikeType = ref('')
const selectedRideType = ref('')
const isDistanceFilterOpen = ref(false)
const isLoading = ref(false)
const errorMessage = ref('')
const profileAvatarUrl = ref<string | null>(null)
const { user: authUser, isAuthenticated, initializeAuth } = useAuth()
const upcomingLimit = ref(10)
const pastLimit = ref(10)
const difficultyLabels: Record<number, string> = {
  1: 'Découverte',
  2: 'Modéré',
  3: 'Sportif',
  4: 'Compétition',
}

const activeFilterCount = computed(
  () =>
    Number(minDistance.value !== null) +
    Number(maxDistance.value !== null) +
    Number(Boolean(selectedBikeType.value)) +
    Number(Boolean(selectedRideType.value)),
)

const filteredRides = computed(() => {
  const query = searchTerm.value.trim().toLocaleLowerCase()
  return rides.value.filter((ride) => {
    const matchesSearch = !query || ride.name.toLocaleLowerCase().includes(query)
    const matchesMinDistance = minDistance.value === null || ride.distance >= minDistance.value
    const matchesMaxDistance = maxDistance.value === null || ride.distance <= maxDistance.value
    const matchesBikeType = !selectedBikeType.value || ride.bike_type === selectedBikeType.value
    const matchesRideType = !selectedRideType.value || ride.ride_type === selectedRideType.value

    return (
      matchesSearch &&
      matchesMinDistance &&
      matchesMaxDistance &&
      matchesBikeType &&
      matchesRideType
    )
  })
})

const upcomingRides = computed(() =>
  filteredRides.value.filter(
    (ride) => new Date(`${ride.date}T${ride.time}`).getTime() >= Date.now(),
  ),
)
const followingRides = computed(() => upcomingRides.value.slice(0, upcomingLimit.value))
const pastRides = computed(() =>
  filteredRides.value
    .filter((ride) => new Date(`${ride.date}T${ride.time}`).getTime() < Date.now())
    .sort(
      (firstRide, secondRide) =>
        new Date(`${secondRide.date}T${secondRide.time}`).getTime() -
        new Date(`${firstRide.date}T${firstRide.time}`).getTime(),
    ),
)
const visiblePastRides = computed(() => pastRides.value.slice(0, pastLimit.value))
const hasMoreUpcoming = computed(() => upcomingRides.value.length > followingRides.value.length)
const hasMorePast = computed(() => pastRides.value.length > visiblePastRides.value.length)

const nextScheduledRide = computed(() => upcomingRides.value[0] ?? null)
const totalUpcomingDistance = computed(() =>
  upcomingRides.value.reduce((acc, ride) => acc + Number(ride.distance || 0), 0),
)

const formatRideDate = (date: string) =>
  new Date(`${date}T00:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })

const formatNewsDate = (isoDate: string) =>
  new Date(isoDate).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })

// Garde uniquement les 3 dernières actualités
const bannerNewsItems = computed(() => latestNews.value.slice(0, 3))
const emptyNewsSlots = computed(() => Math.max(0, 3 - bannerNewsItems.value.length))

watch([searchTerm, minDistance, maxDistance, selectedBikeType, selectedRideType], () => {
  upcomingLimit.value = 10
  pastLimit.value = 10
})

const updateDistanceFilter = (bound: 'min' | 'max', event: Event) => {
  const rawValue = (event.target as HTMLInputElement).value
  const parsedValue = rawValue === '' ? null : Number(rawValue)
  const distance = parsedValue !== null && Number.isFinite(parsedValue) ? parsedValue : null

  if (bound === 'min') minDistance.value = distance
  else maxDistance.value = distance
}

const clearFilters = () => {
  minDistance.value = null
  maxDistance.value = null
  selectedBikeType.value = ''
  selectedRideType.value = ''
}

const fetchLatestNews = async () => {
  try {
    const supabase = getSupabaseClient()
    const { data, error } = await supabase
      .from('news')
      .select('id, title, summary, category, bike_type, image_url, created_at')
      .order('created_at', { ascending: false })
      .limit(3)

    if (!error && data) {
      latestNews.value = data
    }
  } catch {
    latestNews.value = []
  }
}

const fetchRides = async () => {
  isLoading.value = true
  errorMessage.value = ''

  try {
    const supabase = getSupabaseClient()
    const { data, error } = await supabase
      .from('rides')
      .select(
        'id, name, date, time, distance, bike_type, ride_type, start_location, difficulty, image_url, gpx_id',
      )
      .order('date', { ascending: true })
      .order('time', { ascending: true })

    if (error) throw error
    const ridesData = data ?? []
    const gpxIds = [...new Set(ridesData.flatMap((ride) => (ride.gpx_id ? [ride.gpx_id] : [])))]
    const fileUrlByGpxId = new Map<string, string>()

    if (authUser.value && gpxIds.length) {
      const { data: gpxTracks, error: gpxError } = await supabase
        .from('gpx_tracks')
        .select('id, file_url')
        .in('id', gpxIds)

      if (gpxError) throw gpxError
      for (const gpxTrack of gpxTracks ?? []) fileUrlByGpxId.set(gpxTrack.id, gpxTrack.file_url)
    }

    rides.value = ridesData.map((ride) => ({
      ...ride,
      gpx_file_url: ride.gpx_id ? (fileUrlByGpxId.get(ride.gpx_id) ?? null) : null,
    }))
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Impossible de charger les sorties.'
  } finally {
    isLoading.value = false
  }
}

watch(
  authUser,
  async (user) => {
    profileAvatarUrl.value = null
    if (!user) return

    try {
      const { data, error } = await getSupabaseClient()
        .from('users')
        .select('avatar_url')
        .eq('id', user.id)
        .maybeSingle()

      if (!error && authUser.value?.id === user.id) {
        profileAvatarUrl.value = data?.avatar_url ?? null
      }
    } catch {
      profileAvatarUrl.value = null
    }
  },
  { immediate: true },
)

onMounted(async () => {
  await initializeAuth().catch(() => undefined)
  await Promise.all([fetchRides(), fetchLatestNews()])
})
</script>

<template>
  <main class="home-page min-h-screen px-4 pb-28 pt-7 sm:px-6 lg:px-8">
    <!-- En-tête avec bouton Actualités au milieu -->
    <header class="mx-auto mb-6 grid max-w-7xl grid-cols-[1fr_auto_1fr] items-center gap-3">
      <div>
        <p class="home-kicker mb-1 text-xs font-bold uppercase text-emerald-300">
          Roche Vendée Cyclisme
        </p>
        <h1 class="text-2xl font-extrabold text-white sm:text-3xl">RVC Sorties</h1>
      </div>

      <router-link
        to="/news"
        aria-label="Consulter les actualités du club"
        class="group flex items-center gap-2 rounded-full border border-emerald-400/30 bg-[#156555]/80 px-3.5 py-2 text-xs font-bold text-white shadow-lg shadow-black/25 backdrop-blur-xl transition-all hover:border-white/40 hover:bg-[#156555] sm:px-4 sm:text-sm"
      >
        <span class="relative flex h-2 w-2">
          <span
            class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-300 opacity-75"
          ></span>
          <span class="relative inline-flex h-2 w-2 rounded-full bg-emerald-300"></span>
        </span>
        <Newspaper class="h-4 w-4 text-emerald-200 transition-transform group-hover:scale-110" />
        <span>Actualités</span>
      </router-link>

      <div class="flex justify-end">
        <router-link
          to="/profile"
          aria-label="Ouvrir mon profil"
          class="flex h-11 w-11 items-center justify-center overflow-hidden rounded-full border border-white/15 bg-white/10 text-white shadow-lg shadow-black/20 backdrop-blur-xl transition-colors hover:bg-white/15"
        >
          <img
            v-if="profileAvatarUrl"
            :src="profileAvatarUrl"
            alt="Photo de profil"
            class="h-full w-full object-cover"
          />
          <UserRound v-else class="h-5 w-5" />
        </router-link>
      </div>
    </header>

    <!-- Bandeau d'actualités du club (3 actualités + emplacements "Rien à signaler") -->
    <section
      aria-label="Activité et actualités du club"
      class="mx-auto mb-7 max-w-7xl rounded-3xl border border-white/15 bg-gradient-to-br from-[#156555]/40 via-[#060505]/85 to-[#661b23]/40 p-4 shadow-xl backdrop-blur-xl sm:p-5"
    >
      <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
        <div class="flex flex-wrap items-center gap-3">
          <div class="flex items-center gap-2">
            <span
              class="flex h-7 w-7 items-center justify-center rounded-full bg-[#156555] text-emerald-200"
            >
              <Newspaper class="h-4 w-4" />
            </span>
            <h2 class="text-sm font-extrabold uppercase tracking-wide text-white">
              Actualités du club
            </h2>
          </div>

          <!-- Pastille résumé de l'activité RVC -->
          <div
            class="flex flex-wrap items-center gap-2 rounded-full border border-emerald-400/25 bg-black/40 px-3 py-1 text-xs text-white/85"
          >
            <span class="font-bold text-emerald-300">
              {{ upcomingRides.length }} sortie{{ upcomingRides.length > 1 ? 's' : '' }} au
              programme
            </span>
            <span class="text-white/40">·</span>
            <span
              >Cumul : <strong class="text-white">{{ totalUpcomingDistance }} km</strong></span
            >
          </div>
        </div>

        <router-link
          to="/news"
          class="inline-flex items-center gap-1 text-xs font-bold text-emerald-300 transition-colors hover:text-white"
        >
          <span>Voir toute l'actu</span>
          <ArrowRight class="h-3.5 w-3.5" />
        </router-link>
      </div>

      <!-- Grille de 3 emplacements : Actualités réelles + cases "Rien à signaler" pour compléter à 3 -->
      <div class="grid gap-3.5 md:grid-cols-3">
        <router-link
          v-for="item in bannerNewsItems"
          :key="item.id"
          to="/news"
          class="group flex flex-col overflow-hidden rounded-2xl border border-white/15 bg-black/50 text-white shadow-lg transition-all hover:-translate-y-0.5 hover:border-emerald-400/40 hover:bg-black/65"
        >
          <!-- Image de l'actualité -->
          <div class="relative h-32 w-full overflow-hidden bg-white/5">
            <img
              v-if="item.image_url"
              :src="item.image_url"
              :alt="item.title"
              class="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
              loading="lazy"
            />
            <div
              v-else
              class="flex h-full flex-col items-center justify-center gap-1 bg-gradient-to-br from-[#156555]/50 to-[#661b23]/40 text-white/70"
            >
              <Newspaper class="h-6 w-6 text-emerald-300" />
              <span class="text-[11px] font-semibold">Actualité RVC</span>
            </div>

            <div class="absolute inset-x-2.5 top-2.5 flex items-center justify-between gap-2">
              <span
                class="rounded-full bg-[#661b23] px-2.5 py-0.5 text-[10px] font-bold uppercase text-white shadow"
              >
                {{ item.category }}
              </span>
              <span
                class="rounded-full bg-black/60 px-2 py-0.5 text-[10px] font-semibold text-white/90 backdrop-blur-md"
              >
                {{ formatNewsDate(item.created_at) }}
              </span>
            </div>
          </div>

          <!-- Texte de l'actualité -->
          <div class="flex flex-1 flex-col justify-between p-3.5">
            <div>
              <h3
                class="line-clamp-1 text-sm font-extrabold text-white group-hover:text-emerald-300"
              >
                {{ item.title }}
              </h3>
              <p class="mt-1 line-clamp-2 text-xs text-white/75">
                {{ item.summary || 'Découvrir cette actualité du club' }}
              </p>
            </div>

            <div
              class="mt-3 flex items-center justify-between text-[11px] font-bold text-emerald-300"
            >
              <span class="flex items-center gap-1">
                <Bike v-if="item.bike_type" class="h-3.5 w-3.5" />
                {{ item.bike_type ? `Spécialité ${item.bike_type}` : 'Vie du club' }}
              </span>
              <ArrowRight class="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
            </div>
          </div>
        </router-link>

        <!-- Cases restantes (1, 2 ou 3) s'il n'y a pas au moins 3 actualités -->
        <div
          v-for="slot in emptyNewsSlots"
          :key="`empty-news-${slot}`"
          class="flex min-h-48 flex-col items-center justify-center rounded-2xl border border-dashed border-white/15 bg-black/30 p-4 text-center"
        >
          <Newspaper class="mb-2 h-5 w-5 text-white/30" />
          <p class="text-xs font-bold uppercase tracking-wider text-white/60">Rien à signaler</p>
          <p class="mt-1 text-[11px] text-white/40">Aucune autre actualité récente</p>
        </div>
      </div>
    </section>

    <div class="mx-auto mb-7 max-w-7xl space-y-3">
      <label class="relative block">
        <Search class="absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-black" />

        <input
          v-model="searchTerm"
          type="search"
          placeholder="Rechercher..."
          class="w-full rounded-full border border-white/60 bg-white py-3 pl-12 pr-4 placeholder:text-gray-500 shadow-lg shadow-black/10 outline-none focus:ring-2 focus:ring-emerald-400"
        />
      </label>

      <div class="relative z-30">
        <div class="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
          <button
            type="button"
            :aria-expanded="isDistanceFilterOpen"
            class="flex min-h-11 items-center gap-2 rounded-full border border-gray-200 bg-white px-4 text-sm font-semibold text-gray-900 transition-colors hover:bg-gray-100"
            @click="isDistanceFilterOpen = !isDistanceFilterOpen"
          >
            <SlidersHorizontal class="h-4 w-4" />
            Kilomètres
            <span
              v-if="activeFilterCount"
              class="flex h-5 min-w-5 items-center justify-center rounded-full bg-gray-900 px-1 text-xs text-white"
            >
              {{ activeFilterCount }}
            </span>
            <ChevronDown class="h-4 w-4" />
          </button>

          <label class="relative shrink-0">
            <span class="sr-only">Type de vélo</span>
            <select
              v-model="selectedBikeType"
              class="min-h-11 appearance-none rounded-full border border-gray-200 bg-white py-2 pl-4 pr-9 text-sm font-semibold text-gray-900 outline-none hover:bg-gray-100 focus:ring-2 focus:ring-red-500"
            >
              <option value="">Type de vélo</option>
              <option value="Route">Route</option>
              <option value="Gravel">Gravel</option>
              <option value="VTT">VTT</option>
            </select>
            <ChevronDown
              class="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600"
            />
          </label>

          <label class="relative shrink-0">
            <span class="sr-only">Type de sortie</span>
            <select
              v-model="selectedRideType"
              class="min-h-11 appearance-none rounded-full border border-gray-200 bg-white py-2 pl-4 pr-9 text-sm font-semibold text-gray-900 outline-none hover:bg-gray-100 focus:ring-2 focus:ring-red-500"
            >
              <option value="">Club ou libre</option>
              <option value="Club">Club</option>
              <option value="Libre">Libre</option>
              <option value="E-Bike">E-Bike</option>
            </select>
            <ChevronDown
              class="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600"
            />
          </label>

          <button
            v-if="activeFilterCount"
            type="button"
            class="min-h-11 shrink-0 rounded-full px-3 text-sm font-semibold text-gray-600 hover:bg-gray-100"
            @click="clearFilters"
          >
            Effacer
          </button>
        </div>

        <div
          v-if="isDistanceFilterOpen"
          class="absolute left-0 top-full z-50 mt-2 w-[min(19rem,calc(100vw-2rem))] rounded-2xl border border-gray-200 bg-white p-4 shadow-xl"
        >
          <h2 class="mb-3 text-sm font-bold text-gray-900">Distance (km)</h2>
          <div class="grid grid-cols-2 gap-3">
            <label class="text-xs font-semibold text-gray-600">
              Minimum
              <input
                :value="minDistance ?? ''"
                type="number"
                min="0"
                placeholder="0"
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-red-500"
                @input="updateDistanceFilter('min', $event)"
              />
            </label>
            <label class="text-xs font-semibold text-gray-600">
              Maximum
              <input
                :value="maxDistance ?? ''"
                type="number"
                min="0"
                placeholder="Sans limite"
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-red-500"
                @input="updateDistanceFilter('max', $event)"
              />
            </label>
          </div>
          <p
            v-if="minDistance !== null && maxDistance !== null && minDistance > maxDistance"
            role="alert"
            class="mt-3 text-xs text-red-700"
          >
            Le minimum doit être inférieur ou égal au maximum.
          </p>
        </div>
      </div>
    </div>

    <p v-if="errorMessage" role="alert" class="mb-6 rounded-xl bg-red-50 p-3 text-sm text-red-700">
      {{ errorMessage }}
    </p>

    <p v-if="isLoading" class="py-8 text-center text-sm text-gray-500">Chargement des sorties...</p>

    <template v-else-if="!errorMessage">
      <p v-if="filteredRides.length === 0" class="py-8 text-center text-sm text-gray-500">
        {{
          searchTerm || activeFilterCount
            ? 'Aucune sortie ne correspond à ces critères.'
            : 'Aucune sortie pour le moment.'
        }}
      </p>
      <template v-else>
        <section v-if="followingRides.length" class="mx-auto mb-9 max-w-7xl">
          <div class="mb-4 flex items-end justify-between">
            <div>
              <p class="home-kicker text-xs font-bold uppercase text-emerald-300">
                À ne pas manquer
              </p>
              <h2 class="mt-1 text-xl font-bold text-white">Sorties à venir</h2>
            </div>
            <span class="home-muted text-sm text-white/55">{{ upcomingRides.length }}</span>
          </div>
          <div class="home-ride-grid">
            <article
              v-for="ride in followingRides"
              :key="ride.id"
              data-ride-card
              class="home-ride-card"
            >
              <router-link :to="{ name: 'ride-detail', params: { id: ride.id } }">
                <div
                  class="home-card-media relative aspect-[1.15/1] w-full overflow-hidden bg-gray-200"
                >
                  <img
                    v-if="ride.image_url"
                    :src="ride.image_url"
                    :alt="`Image de la sortie ${ride.name}`"
                    class="h-full w-full object-cover"
                    loading="lazy"
                  />
                  <GpxTracePreview
                    v-else-if="ride.gpx_file_url"
                    :file-url="ride.gpx_file_url"
                    :title="ride.name"
                  />
                  <div
                    v-else
                    class="flex h-full flex-col items-center justify-center gap-2 text-sm text-gray-500"
                  >
                    <ImageIcon class="h-7 w-7" />
                    <span>Image à venir</span>
                  </div>
                  <div class="absolute inset-x-2 top-2 flex flex-wrap gap-1.5">
                    <span
                      v-if="ride.bike_type"
                      class="rounded-full border border-white/30 bg-black/45 px-2 py-1 text-[10px] font-bold text-white backdrop-blur-md"
                    >
                      <Bike class="mr-1 inline h-3 w-3" />{{ ride.bike_type }}
                    </span>
                    <span
                      v-if="ride.ride_type"
                      class="rounded-full border border-white/30 bg-black/45 px-2 py-1 text-[10px] font-bold text-white backdrop-blur-md"
                    >
                      {{ ride.ride_type }}
                    </span>
                  </div>
                </div>
                <div class="flex flex-1 flex-col gap-2.5 p-3 sm:p-4">
                  <h3
                    class="line-clamp-2 min-h-10 text-sm font-bold leading-5 text-gray-900 sm:text-base"
                  >
                    {{ ride.name }}
                  </h3>
                  <div class="space-y-1.5 text-xs text-gray-600 sm:text-sm">
                    <p class="flex items-center gap-1.5">
                      <CalendarDays class="h-3.5 w-3.5 shrink-0" />{{ formatRideDate(ride.date) }}
                    </p>
                    <p class="flex items-center gap-1.5">
                      <Clock3 class="h-3.5 w-3.5 shrink-0" />{{ ride.time.slice(0, 5) }}
                      <span class="ml-1">· {{ ride.distance }} km</span>
                    </p>
                    <p v-if="ride.start_location" class="flex min-w-0 items-center gap-1.5">
                      <MapPin class="h-3.5 w-3.5 shrink-0" />
                      <span class="truncate">{{ ride.start_location }}</span>
                    </p>
                    <p
                      v-if="ride.difficulty"
                      class="flex items-center gap-1.5 font-semibold text-emerald-800"
                    >
                      <Bike class="h-3.5 w-3.5 shrink-0" />{{ ride.difficulty }} ·
                      {{ difficultyLabels[ride.difficulty] }}
                    </p>
                  </div>
                  <span
                    class="home-card-action mt-auto flex min-h-9 items-center justify-center rounded-xl bg-gray-900 text-xs font-bold text-white sm:text-sm"
                  >
                    <span class="home-card-action-label">Détails</span>
                  </span>
                </div>
              </router-link>
            </article>
            <button
              v-if="hasMoreUpcoming"
              type="button"
              class="min-h-11 rounded-xl border border-white/15 bg-white/5 px-4 text-sm font-semibold text-white/80 transition-colors hover:bg-white/10"
              @click="upcomingLimit += 10"
            >
              Afficher 10 autres sorties
            </button>
          </div>
        </section>
        <p v-else class="home-muted mb-8 text-sm text-white/55">Aucune sortie à venir.</p>

        <section
          v-if="pastRides.length"
          class="mx-auto mb-8 max-w-7xl border-t border-white/10 pt-6"
        >
          <div class="mb-4">
            <p class="home-muted text-xs font-bold uppercase text-white/45">Le club en images</p>
            <h2 class="mt-1 text-xl font-bold text-white">Sorties passées</h2>
          </div>
          <div class="home-ride-grid">
            <article
              v-for="ride in visiblePastRides"
              :key="ride.id"
              data-ride-card
              class="home-ride-card"
            >
              <router-link :to="{ name: 'ride-detail', params: { id: ride.id } }">
                <div
                  class="home-card-media relative aspect-[1.15/1] w-full overflow-hidden bg-gray-200"
                >
                  <img
                    v-if="ride.image_url"
                    :src="ride.image_url"
                    :alt="`Image de la sortie ${ride.name}`"
                    class="h-full w-full object-cover"
                    loading="lazy"
                  />
                  <GpxTracePreview
                    v-else-if="ride.gpx_file_url"
                    :file-url="ride.gpx_file_url"
                    :title="ride.name"
                  />
                  <div
                    v-else
                    class="flex h-full flex-col items-center justify-center gap-2 text-sm text-gray-500"
                  >
                    <ImageIcon class="h-7 w-7" />
                    <span>Image à venir</span>
                  </div>
                  <div class="absolute inset-x-2 top-2 flex flex-wrap gap-1.5">
                    <span
                      v-if="ride.bike_type"
                      class="rounded-full border border-white/30 bg-black/45 px-2 py-1 text-[10px] font-bold text-white backdrop-blur-md"
                    >
                      <Bike class="mr-1 inline h-3 w-3" />{{ ride.bike_type }}
                    </span>
                    <span
                      v-if="ride.ride_type"
                      class="rounded-full border border-white/30 bg-black/45 px-2 py-1 text-[10px] font-bold text-white backdrop-blur-md"
                    >
                      {{ ride.ride_type }}
                    </span>
                  </div>
                </div>
                <div class="flex flex-1 flex-col gap-2.5 p-3 sm:p-4">
                  <h3
                    class="line-clamp-2 min-h-10 text-sm font-bold leading-5 text-gray-900 sm:text-base"
                  >
                    {{ ride.name }}
                  </h3>
                  <div class="space-y-1.5 text-xs text-gray-600 sm:text-sm">
                    <p class="flex items-center gap-1.5">
                      <CalendarDays class="h-3.5 w-3.5 shrink-0" />{{ formatRideDate(ride.date) }}
                    </p>
                    <p class="flex items-center gap-1.5">
                      <Clock3 class="h-3.5 w-3.5 shrink-0" />{{ ride.time.slice(0, 5) }}
                      <span class="ml-1">· {{ ride.distance }} km</span>
                    </p>
                    <p v-if="ride.start_location" class="flex min-w-0 items-center gap-1.5">
                      <MapPin class="h-3.5 w-3.5 shrink-0" />
                      <span class="truncate">{{ ride.start_location }}</span>
                    </p>
                    <p
                      v-if="ride.difficulty"
                      class="flex items-center gap-1.5 font-semibold text-emerald-800"
                    >
                      <Bike class="h-3.5 w-3.5 shrink-0" />{{ ride.difficulty }} ·
                      {{ difficultyLabels[ride.difficulty] }}
                    </p>
                  </div>
                  <span
                    class="home-card-action mt-auto flex min-h-9 items-center justify-center rounded-xl bg-gray-900 text-xs font-bold text-white sm:text-sm"
                  >
                    <span class="home-card-action-label">Détails</span>
                  </span>
                </div>
              </router-link>
            </article>
            <button
              v-if="hasMorePast"
              type="button"
              class="min-h-11 rounded-xl border border-white/15 bg-white/5 px-4 text-sm font-semibold text-white/80 transition-colors hover:bg-white/10"
              @click="pastLimit += 10"
            >
              Afficher 10 autres sorties
            </button>
          </div>
        </section>
      </template>
    </template>

    <router-link
      v-if="isAuthenticated"
      to="/ride/new"
      class="mx-auto flex min-h-12 w-full max-w-xl items-center justify-center gap-2 rounded-xl bg-red-600 px-4 text-sm font-semibold text-white transition-colors hover:bg-red-700"
    >
      <Plus class="h-5 w-5" />
      <span>Créer une sortie</span>
    </router-link>
  </main>
</template>
