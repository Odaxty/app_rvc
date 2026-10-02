<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ArrowDown, Download, Search, X } from 'lucide-vue-next'
import { getSupabaseClient } from '../supabase.ts'
import AddressAutocomplete from '../components/AddressAutocomplete.vue'

interface GpxTrack {
  id: string
  title: string
  file_url: string
  start_location: string | null
  end_location: string | null
  distance: number | null
  created_at: string
}

const pageSize = 10
const route = useRoute()
const isMyTracks = ref(false)
const gpxTracks = ref<GpxTrack[]>([])
const startLocation = ref('')
const endLocation = ref('')
const minDistance = ref<number | null>(null)
const maxDistance = ref<number | null>(null)
const appliedFilters = ref({
  startLocation: '',
  endLocation: '',
  minDistance: null as number | null,
  maxDistance: null as number | null,
})
const isLoading = ref(true)
const isLoadingMore = ref(false)
const hasMore = ref(false)
const errorMessage = ref('')
const filterError = ref('')
const downloadError = ref('')
const downloadingId = ref<string | null>(null)
let offset = 0

const fetchTracks = async (reset = false) => {
  if (reset) {
    offset = 0
    gpxTracks.value = []
    hasMore.value = false
    isLoading.value = true
  } else {
    if (isLoadingMore.value || !hasMore.value) return
    isLoadingMore.value = true
  }

  errorMessage.value = ''

  try {
    const filters = appliedFilters.value
    let query = getSupabaseClient()
      .from('gpx_tracks')
      .select('id, title, file_url, start_location, end_location, distance, created_at', {
        count: 'exact',
      })
      .order('created_at', { ascending: false })

    if (isMyTracks.value) {
      const {
        data: { session },
        error: sessionError,
      } = await getSupabaseClient().auth.getSession()
      if (sessionError) throw sessionError
      if (!session) throw new Error('Connecte-toi pour consulter tes parcours GPX.')
      query = query.eq('user_id', session.user.id)
    }

    if (filters.startLocation) {
      query = query.ilike('start_location', `%${filters.startLocation}%`)
    }
    if (filters.endLocation) {
      query = query.ilike('end_location', `%${filters.endLocation}%`)
    }
    if (filters.minDistance !== null) query = query.gte('distance', filters.minDistance)
    if (filters.maxDistance !== null) query = query.lte('distance', filters.maxDistance)

    const { data, count, error } = await query.range(offset, offset + pageSize - 1)
    if (error) throw error

    const page = data ?? []
    gpxTracks.value = reset ? page : [...gpxTracks.value, ...page]
    offset += page.length
    hasMore.value = offset < (count ?? offset)
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Impossible de charger les parcours GPX.'
  } finally {
    isLoading.value = false
    isLoadingMore.value = false
  }
}

const applyFilters = async () => {
  filterError.value = ''
  if (
    minDistance.value !== null &&
    maxDistance.value !== null &&
    minDistance.value > maxDistance.value
  ) {
    filterError.value = 'La distance minimale doit être inférieure ou égale à la distance maximale.'
    return
  }

  appliedFilters.value = {
    startLocation: startLocation.value.trim(),
    endLocation: endLocation.value.trim(),
    minDistance: typeof minDistance.value === 'number' ? minDistance.value : null,
    maxDistance: typeof maxDistance.value === 'number' ? maxDistance.value : null,
  }
  await fetchTracks(true)
}

const clearFilters = async () => {
  startLocation.value = ''
  endLocation.value = ''
  minDistance.value = null
  maxDistance.value = null
  filterError.value = ''
  appliedFilters.value = {
    startLocation: '',
    endLocation: '',
    minDistance: null,
    maxDistance: null,
  }
  await fetchTracks(true)
}

const downloadTrack = async (track: GpxTrack) => {
  downloadingId.value = track.id
  downloadError.value = ''

  try {
    const response = await fetch(track.file_url)
    if (!response.ok) throw new Error('Le fichier GPX ne peut pas être téléchargé.')

    const objectUrl = URL.createObjectURL(await response.blob())
    const link = document.createElement('a')
    link.href = objectUrl
    link.download = `${track.title.replace(/[^a-z0-9]+/gi, '-')}.gpx`
    document.body.append(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(objectUrl)
  } catch (error) {
    downloadError.value =
      error instanceof Error ? error.message : 'Impossible de télécharger ce GPX.'
  } finally {
    downloadingId.value = null
  }
}

watch(
  () => route.query.mine,
  (mine) => {
    isMyTracks.value = mine === '1'
    void fetchTracks(true)
  },
  { immediate: true },
)
</script>

<template>
  <main class="app-page min-h-screen bg-gray-50 px-4 pt-8 pb-24">
    <header class="mb-6">
      <h1 class="app-page-title text-2xl font-bold text-gray-900">
        {{ isMyTracks ? 'Mes GPXs' : 'Parcours GPX' }}
      </h1>
    </header>

    <form
      @submit.prevent="applyFilters"
      class="surface-card mb-6 space-y-4 rounded-2xl bg-white p-4 shadow-sm"
    >
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <AddressAutocomplete
          id="gpx-filter-start"
          v-model="startLocation"
          label="Départ"
          placeholder="Ex. La Roche-sur-Yon"
        />
        <AddressAutocomplete
          id="gpx-filter-end"
          v-model="endLocation"
          label="Arrivée"
          placeholder="Ex. Les Sables-d’Olonne"
        />
        <label class="block text-sm font-semibold text-gray-700">
          Distance minimale (km)
          <input
            v-model.number="minDistance"
            type="number"
            min="0"
            step="1"
            class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          />
        </label>
        <label class="block text-sm font-semibold text-gray-700">
          Distance maximale (km)
          <input
            v-model.number="maxDistance"
            type="number"
            min="0"
            step="1"
            class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          />
        </label>
      </div>

      <p v-if="filterError" role="alert" class="text-sm text-red-700">{{ filterError }}</p>
      <div class="flex flex-wrap gap-3">
        <button
          type="submit"
          class="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-gray-900 px-4 text-sm font-semibold text-white transition-colors hover:bg-black"
        >
          <Search class="h-4 w-4" />
          Filtrer
        </button>
        <button
          type="button"
          class="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-gray-200 px-4 text-sm font-semibold text-gray-700 transition-colors hover:bg-gray-50"
          @click="clearFilters"
        >
          <X class="h-4 w-4" />
          Effacer
        </button>
      </div>
    </form>

    <p v-if="errorMessage" role="alert" class="mb-4 rounded-xl bg-red-50 p-3 text-sm text-red-700">
      {{ errorMessage }}
    </p>
    <p v-if="downloadError" role="alert" class="mb-4 rounded-xl bg-red-50 p-3 text-sm text-red-700">
      {{ downloadError }}
    </p>

    <p v-if="isLoading" class="py-8 text-center text-sm text-gray-500">
      Chargement des parcours...
    </p>
    <p
      v-else-if="gpxTracks.length === 0 && !errorMessage"
      class="py-8 text-center text-sm text-gray-500"
    >
      {{
        isMyTracks
          ? 'Tu n’as pas encore envoyé de parcours GPX.'
          : 'Aucun parcours ne correspond à ces filtres.'
      }}
    </p>

    <div v-else class="space-y-3">
      <article
        v-for="track in gpxTracks"
        :key="track.id"
        class="surface-card flex items-center gap-4 rounded-2xl border border-gray-100 bg-white p-4 shadow-sm"
      >
        <div
          class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-green-50 text-green-700"
        >
          <Download class="h-5 w-5" />
        </div>
        <div class="min-w-0 flex-1">
          <h2 class="truncate font-bold text-gray-900">{{ track.title }}</h2>
          <p class="mt-1 text-sm text-gray-500">
            {{ track.start_location || 'Départ non renseigné' }}
            <span aria-hidden="true">→</span>
            {{ track.end_location || 'Arrivée non renseignée' }}
          </p>
          <p class="mt-1 text-sm font-medium text-gray-700">
            {{ track.distance !== null ? `${track.distance} km` : 'Distance non renseignée' }}
          </p>
          <router-link
            :to="{ name: 'gpx-detail', params: { id: track.id } }"
            class="mt-3 inline-flex min-h-10 items-center rounded-lg bg-gray-100 px-3 text-sm font-semibold text-gray-800 transition-colors hover:bg-gray-200"
          >
            Afficher
          </router-link>
        </div>
        <button
          type="button"
          :aria-label="`Télécharger ${track.title}`"
          :title="downloadingId === track.id ? 'Téléchargement...' : 'Télécharger le GPX'"
          :disabled="downloadingId === track.id"
          class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-gray-700 transition-colors hover:bg-gray-100 disabled:opacity-50"
          @click="downloadTrack(track)"
        >
          <Download class="h-5 w-5" />
        </button>
      </article>

      <button
        v-if="hasMore"
        type="button"
        :disabled="isLoadingMore"
        aria-label="Charger 10 autres parcours GPX"
        title="Charger 10 autres parcours"
        class="mx-auto flex h-11 w-11 items-center justify-center rounded-full border border-gray-200 bg-white text-gray-700 transition-colors hover:bg-gray-100 disabled:opacity-50"
        @click="fetchTracks()"
      >
        <ArrowDown class="h-5 w-5" />
      </button>
      <p v-if="isLoadingMore" class="py-2 text-center text-sm text-gray-500">
        Chargement des parcours suivants...
      </p>
    </div>
  </main>
</template>
