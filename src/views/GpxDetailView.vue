<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Download } from 'lucide-vue-next'
import RideGpxMap from '../components/RideGpxMap.vue'
import { getSupabaseClient } from '../supabase.ts'

interface GpxTrack {
  id: string
  title: string
  file_url: string
  start_location: string | null
  end_location: string | null
  distance: number | null
  created_at: string
}

const route = useRoute()
const router = useRouter()
const track = ref<GpxTrack | null>(null)
const isLoading = ref(true)
const errorMessage = ref('')
const isDownloading = ref(false)
const downloadError = ref('')

watch(
  () => route.params.id,
  async (id) => {
    if (typeof id !== 'string') return

    isLoading.value = true
    errorMessage.value = ''

    try {
      const { data, error } = await getSupabaseClient()
        .from('gpx_tracks')
        .select('id, title, file_url, start_location, end_location, distance, created_at')
        .eq('id', id)
        .single()

      if (error) throw error
      track.value = data
    } catch (error) {
      errorMessage.value =
        error instanceof Error ? error.message : 'Impossible de charger ce parcours.'
    } finally {
      isLoading.value = false
    }
  },
  { immediate: true },
)

const downloadTrack = async () => {
  if (!track.value) return

  isDownloading.value = true
  downloadError.value = ''

  try {
    const response = await fetch(track.value.file_url)
    if (!response.ok) throw new Error('Le fichier GPX ne peut pas être téléchargé.')

    const objectUrl = URL.createObjectURL(await response.blob())
    const link = document.createElement('a')
    link.href = objectUrl
    link.download = `${track.value.title.replace(/[^a-z0-9]+/gi, '-')}.gpx`
    document.body.append(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(objectUrl)
  } catch (error) {
    downloadError.value =
      error instanceof Error ? error.message : 'Impossible de télécharger ce GPX.'
  } finally {
    isDownloading.value = false
  }
}

const formatCreatedDate = (date: string) =>
  new Date(date).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })
</script>

<template>
  <main class="app-page min-h-screen bg-gray-50 px-4 pt-6 pb-24">
    <header class="mb-6 flex items-center gap-4">
      <button
        type="button"
        aria-label="Retour aux parcours GPX"
        class="app-back-button rounded-full p-2 text-gray-700 transition-colors hover:bg-gray-200"
        @click="router.push('/gpx')"
      >
        <ArrowLeft class="h-6 w-6" />
      </button>
      <h1 class="app-page-title text-2xl font-bold text-gray-900">Détail du parcours</h1>
    </header>

    <p v-if="isLoading" class="py-8 text-center text-sm text-gray-500">Chargement du parcours...</p>
    <p v-else-if="errorMessage" role="alert" class="rounded-xl bg-red-50 p-3 text-sm text-red-700">
      {{ errorMessage }}
    </p>

    <template v-else-if="track">
      <section class="surface-card mb-6 rounded-2xl border border-gray-100 bg-white p-5 shadow-sm">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 class="text-xl font-bold text-gray-900">{{ track.title }}</h2>
            <p class="mt-2 text-sm text-gray-500">
              Ajouté le {{ formatCreatedDate(track.created_at) }}
            </p>
          </div>
          <span class="rounded-lg bg-green-50 px-3 py-2 text-sm font-semibold text-green-800">
            {{ track.distance !== null ? `${track.distance} km` : 'Distance non renseignée' }}
          </span>
        </div>

        <dl class="mt-5 grid grid-cols-1 gap-4 border-t border-gray-100 pt-4 sm:grid-cols-2">
          <div>
            <dt class="text-xs font-semibold uppercase text-gray-500">Départ</dt>
            <dd class="mt-1 font-medium text-gray-900">
              {{ track.start_location || 'Non renseigné' }}
            </dd>
          </div>
          <div>
            <dt class="text-xs font-semibold uppercase text-gray-500">Arrivée</dt>
            <dd class="mt-1 font-medium text-gray-900">
              {{ track.end_location || 'Non renseignée' }}
            </dd>
          </div>
        </dl>

        <div class="mt-5 flex flex-col gap-3 sm:flex-row">
          <button
            type="button"
            :disabled="isDownloading"
            class="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-gray-200 px-4 text-sm font-semibold text-gray-800 transition-colors hover:bg-gray-50 disabled:opacity-50"
            @click="downloadTrack"
          >
            <Download class="h-5 w-5" />
            {{ isDownloading ? 'Téléchargement...' : 'Télécharger le GPX' }}
          </button>
        </div>
        <p v-if="downloadError" role="alert" class="mt-3 text-sm text-red-700">
          {{ downloadError }}
        </p>
      </section>

      <RideGpxMap :file-url="track.file_url" />
    </template>
  </main>
</template>
