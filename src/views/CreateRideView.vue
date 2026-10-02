<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft } from 'lucide-vue-next'
import { getSupabaseClient } from '../supabase.ts'
import { useAuth } from '../composables/useAuth'
import AddressAutocomplete from '../components/AddressAutocomplete.vue'

const router = useRouter()
const { user, initializeAuth } = useAuth()
const isCheckingAuth = ref(true)
const isSubmitting = ref(false)
const errorMessage = ref('')
const errorDetails = ref<string[]>([])
const name = ref('')
const description = ref('')
const date = ref('')
const time = ref('')
const distance = ref<number | null>(null)
const maxParticipants = ref<number | null>(null)
const bikeType = ref<'Route' | 'Gravel' | 'VTT'>('Route')
const rideType = ref<'Club' | 'Libre'>('Club')
const rideStartLocation = ref('')
const difficulty = ref<number | null>(null)
const difficultyLabels = ['Découverte', 'Modéré', 'Sportif', 'Compétition']
const selectedImage = ref<File | null>(null)
const imagePreviewUrl = ref<string | null>(null)
const imageError = ref('')
const imageInput = ref<HTMLInputElement | null>(null)
const selectedGpx = ref<File | null>(null)
const gpxError = ref('')
const gpxInput = ref<HTMLInputElement | null>(null)
const gpxStartLocation = ref('')
const gpxEndLocation = ref('')

const clearImagePreview = () => {
  if (imagePreviewUrl.value) URL.revokeObjectURL(imagePreviewUrl.value)
  imagePreviewUrl.value = null
}

const handleImageChange = (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] ?? null

  imageError.value = ''
  clearImagePreview()
  selectedImage.value = null

  if (!file) return

  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
    imageError.value = 'Choisis une image JPG, PNG ou WebP.'
    input.value = ''
    return
  }

  if (file.size > 5 * 1024 * 1024) {
    imageError.value = 'L’image ne doit pas dépasser 5 Mo.'
    input.value = ''
    return
  }

  selectedImage.value = file
  imagePreviewUrl.value = URL.createObjectURL(file)
}

const removeSelectedImage = () => {
  clearImagePreview()
  selectedImage.value = null
  imageError.value = ''
  if (imageInput.value) imageInput.value.value = ''
}

const handleGpxChange = (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] ?? null

  gpxError.value = ''
  selectedGpx.value = null
  if (!file) return

  if (!file.name.toLowerCase().endsWith('.gpx')) {
    gpxError.value = 'Choisis un fichier GPX.'
    input.value = ''
    return
  }

  if (file.size > 20 * 1024 * 1024) {
    gpxError.value = 'Le fichier GPX ne doit pas dépasser 20 Mo.'
    input.value = ''
    return
  }

  selectedGpx.value = file
}

const removeSelectedGpx = () => {
  selectedGpx.value = null
  gpxStartLocation.value = ''
  gpxEndLocation.value = ''
  gpxError.value = ''
  if (gpxInput.value) gpxInput.value.value = ''
}

onBeforeUnmount(clearImagePreview)

onMounted(async () => {
  try {
    await initializeAuth()
    if (!user.value) await router.replace('/auth')
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Impossible de vérifier la connexion.'
  } finally {
    isCheckingAuth.value = false
  }
})

const createRide = async () => {
  if (!user.value) {
    await router.replace('/auth')
    return
  }

  if (distance.value === null) {
    errorMessage.value = 'Renseigne la distance de la sortie.'
    return
  }
  if (!rideStartLocation.value) {
    errorMessage.value = 'Choisis une adresse de départ dans les suggestions.'
    return
  }
  if (selectedGpx.value && (!gpxStartLocation.value || !gpxEndLocation.value)) {
    errorMessage.value = 'Choisis les lieux de départ et d’arrivée dans les suggestions.'
    return
  }
  if (difficulty.value === null) {
    errorMessage.value = 'Choisis le niveau de difficulté de la sortie.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = ''
  errorDetails.value = []

  const supabase = getSupabaseClient()
  let currentStage = 'préparation de la sortie'
  let uploadedImagePath: string | null = null
  let uploadedGpxPath: string | null = null
  let createdGpxTrackId: string | null = null

  try {
    let imageUrl: string | null = null
    let gpxId: string | null = null

    if (selectedImage.value) {
      currentStage = 'téléversement de l’image dans Storage'
      const extension = selectedImage.value.name.split('.').pop()?.toLowerCase() || 'jpg'
      uploadedImagePath = `${user.value.id}/${crypto.randomUUID()}.${extension}`

      const { error: uploadError } = await supabase.storage
        .from('ride-images')
        .upload(uploadedImagePath, selectedImage.value, {
          cacheControl: '3600',
          contentType: selectedImage.value.type,
          upsert: false,
        })

      if (uploadError) throw uploadError

      imageUrl = supabase.storage.from('ride-images').getPublicUrl(uploadedImagePath).data.publicUrl
    }

    if (selectedGpx.value) {
      currentStage = 'téléversement du fichier GPX dans Storage'
      uploadedGpxPath = `${user.value.id}/${crypto.randomUUID()}.gpx`

      const { error: uploadError } = await supabase.storage
        .from('ride-gpx')
        .upload(uploadedGpxPath, selectedGpx.value, {
          cacheControl: '3600',
          contentType: selectedGpx.value.type || 'application/gpx+xml',
          upsert: false,
        })

      if (uploadError) throw uploadError

      const fileUrl = supabase.storage.from('ride-gpx').getPublicUrl(uploadedGpxPath).data.publicUrl
      currentStage = 'enregistrement du fichier dans gpx_tracks'
      const { data: gpxTrack, error: gpxInsertError } = await supabase
        .from('gpx_tracks')
        .insert({
          user_id: user.value.id,
          title: name.value.trim(),
          file_url: fileUrl,
          start_location: gpxStartLocation.value.trim(),
          end_location: gpxEndLocation.value.trim(),
          distance: distance.value,
        })
        .select('id')
        .single()

      if (gpxInsertError) throw gpxInsertError
      createdGpxTrackId = gpxTrack.id
      gpxId = gpxTrack.id
    }

    currentStage = 'création de la sortie dans rides'
    const { error } = await supabase.from('rides').insert({
      creator_id: user.value.id,
      name: name.value.trim(),
      description: description.value.trim() || null,
      date: date.value,
      time: time.value,
      start_location: rideStartLocation.value,
      distance: distance.value,
      max_participants:
        typeof maxParticipants.value === 'number' && maxParticipants.value > 0
          ? Math.floor(maxParticipants.value)
          : null,
      bike_type: bikeType.value,
      ride_type: rideType.value,
      difficulty: difficulty.value,
      image_url: imageUrl,
      gpx_id: gpxId,
    })

    if (error) throw error
    await router.replace('/')
  } catch (error) {
    console.error(`Échec pendant ${currentStage}`, error)
    errorMessage.value = `Échec pendant ${currentStage}.`
    if (error instanceof Error) errorDetails.value.push(error.message)

    if (typeof error === 'object' && error !== null) {
      const backendError = error as {
        code?: unknown
        details?: unknown
        hint?: unknown
        message?: unknown
      }
      if (backendError.code) errorDetails.value.push(`Code : ${String(backendError.code)}`)
      if (backendError.message && backendError.message !== errorDetails.value[0]) {
        errorDetails.value.push(`Message : ${String(backendError.message)}`)
      }
      if (backendError.details) errorDetails.value.push(`Détails : ${String(backendError.details)}`)
      if (backendError.hint) errorDetails.value.push(`Indication : ${String(backendError.hint)}`)
    }

    if (createdGpxTrackId) {
      await supabase.from('gpx_tracks').delete().eq('id', createdGpxTrackId)
    }
    if (uploadedGpxPath) {
      await supabase.storage.from('ride-gpx').remove([uploadedGpxPath])
    }
    if (uploadedImagePath) {
      await supabase.storage.from('ride-images').remove([uploadedImagePath])
    }
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <main class="min-h-screen bg-gray-50 px-4 pt-6 pb-24">
    <header class="mb-6 flex items-center gap-4">
      <router-link
        to="/"
        aria-label="Retour aux sorties"
        class="rounded-full p-2 text-gray-700 transition-colors hover:bg-gray-200"
      >
        <ArrowLeft class="h-6 w-6" />
      </router-link>
      <h1 class="text-2xl font-bold text-gray-900">Créer une sortie</h1>
    </header>

    <p v-if="isCheckingAuth" class="py-8 text-center text-sm text-gray-500">
      Vérification de la connexion...
    </p>

    <form v-else @submit.prevent="createRide" class="app-form-panel mx-auto max-w-xl space-y-4">
      <div v-if="errorMessage" role="alert" class="rounded-xl bg-red-50 p-3 text-sm text-red-700">
        <p class="font-semibold">{{ errorMessage }}</p>
        <ul v-if="errorDetails.length" class="mt-2 list-inside list-disc space-y-1">
          <li v-for="detail in errorDetails" :key="detail">{{ detail }}</li>
        </ul>
      </div>

      <label class="block text-sm font-semibold text-gray-700">
        Nom de la sortie
        <input
          v-model="name"
          required
          maxlength="120"
          class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
        />
      </label>

      <label class="block text-sm font-semibold text-gray-700">
        Description
        <textarea
          v-model="description"
          rows="3"
          class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
        />
      </label>

      <div>
        <label for="ride-image" class="block text-sm font-semibold text-gray-700">
          Image de la sortie
        </label>
        <input
          id="ride-image"
          ref="imageInput"
          type="file"
          accept="image/jpeg,image/png,image/webp"
          class="mt-1 block w-full rounded-xl border border-gray-200 bg-white p-3 text-sm text-gray-700 file:mr-4 file:rounded-lg file:border-0 file:bg-gray-100 file:px-3 file:py-2 file:font-semibold"
          @change="handleImageChange"
        />
        <p class="mt-1 text-xs text-gray-500">JPG, PNG ou WebP, 5 Mo maximum.</p>
        <p v-if="imageError" role="alert" class="mt-2 text-sm text-red-700">
          {{ imageError }}
        </p>
        <div v-if="imagePreviewUrl" class="mt-3">
          <img
            :src="imagePreviewUrl"
            alt="Aperçu de l’image de la sortie"
            class="aspect-video w-full rounded-xl bg-gray-100 object-cover"
          />
          <button
            type="button"
            class="mt-2 text-sm font-semibold text-red-700 hover:text-red-800"
            @click="removeSelectedImage"
          >
            Retirer l’image
          </button>
        </div>
      </div>

      <div>
        <label for="ride-gpx" class="block text-sm font-semibold text-gray-700">
          Parcours GPX (facultatif)
        </label>
        <input
          id="ride-gpx"
          ref="gpxInput"
          type="file"
          accept=".gpx,application/gpx+xml,application/xml,text/xml"
          class="mt-1 block w-full rounded-xl border border-gray-200 bg-white p-3 text-sm text-gray-700 file:mr-4 file:rounded-lg file:border-0 file:bg-gray-100 file:px-3 file:py-2 file:font-semibold"
          @change="handleGpxChange"
        />
        <p class="mt-1 text-xs text-gray-500">Fichier GPX, 20 Mo maximum.</p>
        <p v-if="gpxError" role="alert" class="mt-2 text-sm text-red-700">{{ gpxError }}</p>
        <div v-if="selectedGpx" class="mt-2 flex items-center justify-between gap-3 text-sm">
          <span class="truncate text-gray-700">{{ selectedGpx.name }}</span>
          <button
            type="button"
            class="shrink-0 font-semibold text-red-700 hover:text-red-800"
            @click="removeSelectedGpx"
          >
            Retirer
          </button>
        </div>
        <div v-if="selectedGpx" class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <AddressAutocomplete
            id="gpx-start-location"
            v-model="gpxStartLocation"
            label="Départ du parcours GPX"
            required
          />
          <AddressAutocomplete
            id="gpx-end-location"
            v-model="gpxEndLocation"
            label="Arrivée du parcours GPX"
            required
          />
          <button
            type="button"
            :disabled="!gpxStartLocation"
            class="w-fit text-sm font-semibold text-red-700 hover:text-red-800 disabled:cursor-not-allowed disabled:text-gray-400 sm:col-span-2"
            @click="gpxEndLocation = gpxStartLocation"
          >
            Même adresse que le départ
          </button>
        </div>
      </div>

      <AddressAutocomplete
        id="ride-start-location"
        v-model="rideStartLocation"
        label="Lieu de départ de la sortie"
        required
      />

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <label class="block text-sm font-semibold text-gray-700">
          Date
          <input
            v-model="date"
            type="date"
            required
            class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          />
        </label>

        <label class="block text-sm font-semibold text-gray-700">
          Heure
          <input
            v-model="time"
            type="time"
            required
            class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          />
        </label>

        <label class="block text-sm font-semibold text-gray-700">
          Distance (km)
          <input
            v-model.number="distance"
            type="number"
            min="1"
            step="0.1"
            required
            class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          />
        </label>

        <label class="block text-sm font-semibold text-gray-700">
          Nombre maximum de participants
          <input
            v-model.number="maxParticipants"
            type="number"
            min="1"
            step="1"
            placeholder="Sans limite"
            class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          />
        </label>

        <label class="block text-sm font-semibold text-gray-700">
          Type de vélo
          <select
            v-model="bikeType"
            required
            class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          >
            <option>Route</option>
            <option>Gravel</option>
            <option>VTT</option>
          </select>
        </label>

        <label class="block text-sm font-semibold text-gray-700">
          Niveau de difficulté
          <select
            v-model="difficulty"
            required
            class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          >
            <option :value="null" disabled>Choisir un niveau</option>
            <option v-for="(label, index) in difficultyLabels" :key="label" :value="index + 1">
              {{ index + 1 }} vélo{{ index ? 's' : '' }} · {{ label }}
            </option>
          </select>
        </label>

        <label class="block text-sm font-semibold text-gray-700 sm:col-span-2">
          Organisation
          <select
            v-model="rideType"
            required
            class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
          >
            <option>Club</option>
            <option>Libre</option>
          </select>
        </label>
      </div>

      <button
        type="submit"
        :disabled="isSubmitting"
        class="w-full rounded-xl bg-green-600 py-3.5 font-bold text-white transition-colors hover:bg-green-700 disabled:opacity-50"
      >
        {{ isSubmitting ? 'Création...' : 'Créer la sortie' }}
      </button>
    </form>
  </main>
</template>
