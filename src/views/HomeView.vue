<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import {
  Bike,
  CalendarDays,
  ChevronDown,
  Clock3,
  Image as ImageIcon,
  MapPin,
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

const rides = ref<Ride[]>([])
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
const formatRideDate = (date: string) =>
  new Date(`${date}T00:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })

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
  await fetchRides()
})
</script>

<template>
  <main class="home-page min-h-screen px-4 pb-28 pt-7 sm:px-6 lg:px-8">
    <header class="mx-auto mb-6 flex max-w-7xl items-center justify-between">
      <div>
        <p class="home-kicker mb-1 text-xs font-bold uppercase text-emerald-300">
          Roche Vendée Cyclisme
        </p>
        <h1 class="text-3xl font-extrabold text-white">RVC Sorties</h1>
      </div>
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
    </header>

    <div class="mx-auto mb-7 max-w-7xl space-y-3">
      <label class="relative block">
        <Search class="absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-500" />
        <input
          v-model="searchTerm"
          type="search"
          placeholder="Rechercher..."
          class="w-full rounded-full border border-white/60 bg-white/95 py-3 pl-12 pr-4 text-gray-900 shadow-lg shadow-black/10 outline-none focus:ring-2 focus:ring-emerald-400"
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
