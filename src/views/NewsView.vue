<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import {
  ArrowLeft,
  Bike,
  CalendarDays,
  ChevronDown,
  Image as ImageIcon,
  Link2,
  Newspaper,
  Pencil,
  Plus,
  Search,
  Trash2,
  UserRound,
  X,
} from 'lucide-vue-next'
import { getSupabaseClient } from '../supabase.ts'
import { useAuth } from '../composables/useAuth'

type NewsCategory = 'Club' | 'Compétition' | 'Événement' | 'Matériel'
type BikeSpecialty = 'Route' | 'Gravel' | 'VTT'

interface AuthorProfile {
  firstname: string
  lastname: string
  level: string | null
  avatar_url: string | null
}

interface LinkedRide {
  id: string
  name: string
  date: string
  distance: number
}

interface NewsItem {
  id: string
  author_id: string
  ride_id: string | null
  title: string
  summary: string | null
  content: string
  category: NewsCategory
  bike_type: BikeSpecialty | null
  image_url: string | null
  created_at: string
  author: AuthorProfile | null
  linkedRide: LinkedRide | null
}

interface RideOption {
  id: string
  name: string
  date: string
}

const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

const newsList = ref<NewsItem[]>([])
const availableRides = ref<RideOption[]>([])
const searchTerm = ref('')
const selectedCategory = ref<string>('')
const selectedBikeType = ref<string>('')
const visibleLimit = ref(10)

const isLoading = ref(false)
const isSubmitting = ref(false)
const errorMessage = ref('')
const formErrorMessage = ref('')
const isModalOpen = ref(false)
const editingNewsId = ref<string | null>(null)
const expandedNewsId = ref<string | null>(null)
const profileAvatarUrl = ref<string | null>(null)

// Champs du formulaire
const newTitle = ref('')
const newSummary = ref('')
const newContent = ref('')
const newCategory = ref<NewsCategory>('Club')
const newBikeType = ref<string>('')
const newRideId = ref<string>('')

// Gestion de l'image (identique au flux des sorties)
const imageInput = ref<HTMLInputElement | null>(null)
const selectedImage = ref<File | null>(null)
const imagePreviewUrl = ref<string | null>(null)
const currentImageUrl = ref<string | null>(null)
const shouldRemoveCurrentImage = ref(false)
const imageError = ref('')

const { user: authUser, isAuthenticated, initializeAuth } = useAuth()

const filteredNews = computed(() => {
  const query = searchTerm.value.trim().toLocaleLowerCase()
  return newsList.value.filter((item) => {
    const matchesSearch =
      !query ||
      item.title.toLocaleLowerCase().includes(query) ||
      (item.summary && item.summary.toLocaleLowerCase().includes(query)) ||
      item.content.toLocaleLowerCase().includes(query)
    const matchesCategory = !selectedCategory.value || item.category === selectedCategory.value
    const matchesBike = !selectedBikeType.value || item.bike_type === selectedBikeType.value

    return matchesSearch && matchesCategory && matchesBike
  })
})

const visibleNews = computed(() => filteredNews.value.slice(0, visibleLimit.value))
const hasMoreNews = computed(() => filteredNews.value.length > visibleNews.value.length)
const activeFilterCount = computed(
  () => Number(Boolean(selectedCategory.value)) + Number(Boolean(selectedBikeType.value)),
)

watch([searchTerm, selectedCategory, selectedBikeType], () => {
  visibleLimit.value = 10
})

const clearFilters = () => {
  selectedCategory.value = ''
  selectedBikeType.value = ''
}

const formatDate = (isoDate: string) =>
  new Date(isoDate).toLocaleDateString('fr-FR', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  })

const toggleExpand = (id: string) => {
  expandedNewsId.value = expandedNewsId.value === id ? null : id
}

// Nettoyage de l'aperçu blob en mémoire
const revokeImagePreview = () => {
  if (imagePreviewUrl.value) {
    URL.revokeObjectURL(imagePreviewUrl.value)
    imagePreviewUrl.value = null
  }
}

const resetImageState = () => {
  revokeImagePreview()
  selectedImage.value = null
  currentImageUrl.value = null
  shouldRemoveCurrentImage.value = false
  imageError.value = ''
  if (imageInput.value) {
    imageInput.value.value = ''
  }
}

const removeSelectedImage = () => {
  revokeImagePreview()
  selectedImage.value = null
  imageError.value = ''
  if (imageInput.value) {
    imageInput.value.value = ''
  }
}

const removeCurrentImage = () => {
  shouldRemoveCurrentImage.value = true
  imageError.value = ''
}

const handleImageChange = (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] ?? null

  imageError.value = ''

  if (!file) {
    removeSelectedImage()
    return
  }

  if (!ALLOWED_IMAGE_TYPES.has(file.type)) {
    imageError.value = 'Format non supporté. Choisissez une image JPG, PNG ou WebP.'
    input.value = ''
    return
  }

  if (file.size > MAX_IMAGE_SIZE_BYTES) {
    imageError.value = 'L’image dépasse la taille maximale autorisée de 5 Mo.'
    input.value = ''
    return
  }

  revokeImagePreview()
  selectedImage.value = file
  imagePreviewUrl.value = URL.createObjectURL(file)
  shouldRemoveCurrentImage.value = false
}

const uploadNewsImage = async (file: File, userId: string): Promise<string> => {
  const supabase = getSupabaseClient()
  const extension = file.name.split('.').pop()?.toLowerCase() || 'jpg'
  const filePath = `news/${userId}/${Date.now()}-${crypto.randomUUID()}.${extension}`

  const { error: uploadError } = await supabase.storage.from('ride-images').upload(filePath, file, {
    cacheControl: '3600',
    upsert: false,
    contentType: file.type,
  })

  if (uploadError) throw uploadError

  const { data } = supabase.storage.from('ride-images').getPublicUrl(filePath)
  return data.publicUrl
}

const openCreateModal = () => {
  editingNewsId.value = null
  newTitle.value = ''
  newSummary.value = ''
  newContent.value = ''
  newCategory.value = 'Club'
  newBikeType.value = ''
  newRideId.value = ''
  formErrorMessage.value = ''
  resetImageState()
  isModalOpen.value = true
}

const openEditModal = (item: NewsItem) => {
  editingNewsId.value = item.id
  newTitle.value = item.title
  newSummary.value = item.summary ?? ''
  newContent.value = item.content
  newCategory.value = item.category
  newBikeType.value = item.bike_type ?? ''
  newRideId.value = item.ride_id ?? ''
  formErrorMessage.value = ''
  resetImageState()
  currentImageUrl.value = item.image_url
  isModalOpen.value = true
}

const closeModal = () => {
  isModalOpen.value = false
  editingNewsId.value = null
  resetImageState()
}

const fetchNews = async () => {
  isLoading.value = true
  errorMessage.value = ''

  try {
    const supabase = getSupabaseClient()
    const { data, error } = await supabase
      .from('news')
      .select(
        'id, author_id, ride_id, title, summary, content, category, bike_type, image_url, created_at',
      )
      .order('created_at', { ascending: false })

    if (error) throw error
    const rows = data ?? []

    const authorIds = [...new Set(rows.map((row) => row.author_id))]
    const rideIds = [...new Set(rows.flatMap((row) => (row.ride_id ? [row.ride_id] : [])))]

    const authorsById = new Map<string, AuthorProfile>()
    const ridesById = new Map<string, LinkedRide>()

    if (authorIds.length) {
      const { data: usersData } = await supabase
        .from('users')
        .select('id, firstname, lastname, level, avatar_url')
        .in('id', authorIds)

      for (const userRow of usersData ?? []) {
        authorsById.set(userRow.id, {
          firstname: userRow.firstname,
          lastname: userRow.lastname,
          level: userRow.level,
          avatar_url: userRow.avatar_url,
        })
      }
    }

    if (rideIds.length) {
      const { data: ridesData } = await supabase
        .from('rides')
        .select('id, name, date, distance')
        .in('id', rideIds)

      for (const rideRow of ridesData ?? []) {
        ridesById.set(rideRow.id, rideRow)
      }
    }

    newsList.value = rows.map((row) => ({
      id: row.id,
      author_id: row.author_id,
      ride_id: row.ride_id,
      title: row.title,
      summary: row.summary,
      content: row.content,
      category: (row.category as NewsCategory) ?? 'Club',
      bike_type: (row.bike_type as BikeSpecialty | null) ?? null,
      image_url: row.image_url,
      created_at: row.created_at,
      author: authorsById.get(row.author_id) ?? null,
      linkedRide: row.ride_id ? (ridesById.get(row.ride_id) ?? null) : null,
    }))
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Impossible de charger les actualités.'
  } finally {
    isLoading.value = false
  }
}

const fetchRideOptions = async () => {
  try {
    const { data } = await getSupabaseClient()
      .from('rides')
      .select('id, name, date')
      .order('date', { ascending: false })
      .limit(25)

    availableRides.value = data ?? []
  } catch {
    availableRides.value = []
  }
}

const handleSaveNews = async () => {
  if (!authUser.value) return
  if (!newTitle.value.trim() || !newContent.value.trim()) {
    formErrorMessage.value = 'Le titre et le contenu sont obligatoires.'
    return
  }
  if (imageError.value) return

  isSubmitting.value = true
  formErrorMessage.value = ''

  try {
    const supabase = getSupabaseClient()
    let finalImageUrl: string | null = shouldRemoveCurrentImage.value ? null : currentImageUrl.value

    if (selectedImage.value) {
      finalImageUrl = await uploadNewsImage(selectedImage.value, authUser.value.id)
    }

    const payload = {
      title: newTitle.value.trim(),
      summary: newSummary.value.trim() || null,
      content: newContent.value.trim(),
      category: newCategory.value,
      bike_type: newBikeType.value ? (newBikeType.value as BikeSpecialty) : null,
      ride_id: newRideId.value || null,
      image_url: finalImageUrl,
    }

    if (editingNewsId.value) {
      const { error } = await supabase
        .from('news')
        .update({ ...payload, updated_at: new Date().toISOString() })
        .eq('id', editingNewsId.value)
        .eq('author_id', authUser.value.id)

      if (error) throw error
    } else {
      const { error } = await supabase.from('news').insert({
        ...payload,
        author_id: authUser.value.id,
      })

      if (error) throw error
    }

    closeModal()
    await fetchNews()
  } catch (error) {
    formErrorMessage.value =
      error instanceof Error ? error.message : 'Erreur lors de l’enregistrement de l’actualité.'
  } finally {
    isSubmitting.value = false
  }
}

const handleDeleteNews = async (newsId: string) => {
  if (!authUser.value) return

  try {
    const { error } = await getSupabaseClient()
      .from('news')
      .delete()
      .eq('id', newsId)
      .eq('author_id', authUser.value.id)

    if (error) throw error
    newsList.value = newsList.value.filter((item) => item.id !== newsId)
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Impossible de supprimer cette actualité.'
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

onBeforeUnmount(() => {
  revokeImagePreview()
})

onMounted(async () => {
  await initializeAuth().catch(() => undefined)
  await Promise.all([fetchNews(), fetchRideOptions()])
})
</script>

<template>
  <main class="home-page min-h-screen px-4 pb-28 pt-7 sm:px-6 lg:px-8">
    <!-- En-tête avec bouton central de retour vers les sorties -->
    <header class="mx-auto mb-6 grid max-w-7xl grid-cols-[1fr_auto_1fr] items-center gap-3">
      <div>
        <p class="home-kicker mb-1 text-xs font-bold uppercase text-emerald-300">
          Roche Vendée Cyclisme
        </p>
        <h1 class="text-2xl font-extrabold text-white sm:text-3xl">RVC Actualités</h1>
      </div>

      <router-link
        to="/"
        aria-label="Retourner aux sorties"
        class="flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-3.5 py-2 text-xs font-bold text-white shadow-lg shadow-black/20 backdrop-blur-xl transition-colors hover:bg-white/20 sm:px-4 sm:text-sm"
      >
        <ArrowLeft class="h-4 w-4 text-emerald-300" />
        <span>Sorties</span>
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

    <!-- Barre de recherche et filtres par spécialisation -->
    <div class="mx-auto mb-7 max-w-7xl space-y-3">
      <label class="relative block">
        <Search class="absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-500" />
        <input
          v-model="searchTerm"
          type="search"
          placeholder="Rechercher une actualité, une course, un compte-rendu..."
          class="w-full rounded-full border border-white/60 bg-white/95 py-3 pl-12 pr-4 text-gray-900 shadow-lg shadow-black/10 outline-none focus:ring-2 focus:ring-emerald-400"
        />
      </label>

      <div class="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
        <label class="relative shrink-0">
          <span class="sr-only">Rubrique</span>
          <select
            v-model="selectedCategory"
            class="min-h-11 appearance-none rounded-full border border-gray-200 bg-white py-2 pl-4 pr-9 text-sm font-semibold text-gray-900 outline-none hover:bg-gray-100 focus:ring-2 focus:ring-red-500"
          >
            <option value="">Toutes les rubriques</option>
            <option value="Club">Vie du Club</option>
            <option value="Compétition">Compétition</option>
            <option value="Événement">Événement</option>
            <option value="Matériel">Matériel & GPX</option>
          </select>
          <ChevronDown
            class="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600"
          />
        </label>

        <label class="relative shrink-0">
          <span class="sr-only">Spécialité vélo</span>
          <select
            v-model="selectedBikeType"
            class="min-h-11 appearance-none rounded-full border border-gray-200 bg-white py-2 pl-4 pr-9 text-sm font-semibold text-gray-900 outline-none hover:bg-gray-100 focus:ring-2 focus:ring-red-500"
          >
            <option value="">Toutes spécialités</option>
            <option value="Route">Route</option>
            <option value="Gravel">Gravel</option>
            <option value="VTT">VTT</option>
          </select>
          <ChevronDown
            class="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600"
          />
        </label>

        <button
          v-if="activeFilterCount"
          type="button"
          class="min-h-11 shrink-0 rounded-full px-3 text-sm font-semibold text-emerald-300 hover:bg-white/10"
          @click="clearFilters"
        >
          Effacer ({{ activeFilterCount }})
        </button>
      </div>
    </div>

    <p
      v-if="errorMessage"
      role="alert"
      class="mx-auto mb-6 max-w-7xl rounded-xl bg-red-50 p-3 text-sm text-red-700"
    >
      {{ errorMessage }}
    </p>

    <p v-if="isLoading" class="py-8 text-center text-sm text-gray-400">
      Chargement des actualités du club...
    </p>

    <!-- Grille Bento des actualités -->
    <section v-else class="mx-auto mb-9 max-w-7xl">
      <div
        v-if="visibleNews.length === 0"
        class="rounded-3xl border border-white/10 bg-white/5 p-8 text-center"
      >
        <Newspaper class="mx-auto mb-3 h-10 w-10 text-emerald-300/70" />
        <p class="text-base font-bold text-white">
          {{
            searchTerm || activeFilterCount
              ? 'Aucune actualité ne correspond à ces filtres.'
              : 'Aucune actualité publiée pour le moment.'
          }}
        </p>
        <p class="mt-1 text-xs text-white/60">
          Les membres connectés peuvent partager les résumés de sorties, annonces et résultats.
        </p>
      </div>

      <div v-else class="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
        <article
          v-for="item in visibleNews"
          :key="item.id"
          class="flex flex-col overflow-hidden rounded-3xl border border-white/15 bg-white shadow-xl transition-transform hover:-translate-y-0.5"
        >
          <!-- En-tête visuel de la carte -->
          <div class="relative aspect-[16/9] w-full overflow-hidden bg-gray-200">
            <img
              v-if="item.image_url"
              :src="item.image_url"
              :alt="item.title"
              class="h-full w-full object-cover"
              loading="lazy"
            />
            <div
              v-else
              class="flex h-full flex-col items-center justify-center gap-1.5 bg-gradient-to-br from-[#156555] to-[#060505] text-white/80"
            >
              <ImageIcon class="h-7 w-7 text-emerald-300" />
              <span class="text-xs font-semibold">Roche Vendée Cyclisme</span>
            </div>

            <div
              class="absolute inset-x-3 top-3 flex flex-wrap items-center justify-between gap-1.5"
            >
              <div class="flex flex-wrap gap-1.5">
                <span
                  class="rounded-full bg-[#661b23] px-2.5 py-1 text-[10px] font-bold uppercase text-white shadow"
                >
                  {{ item.category }}
                </span>
                <span
                  v-if="item.bike_type"
                  class="rounded-full border border-white/30 bg-black/55 px-2.5 py-1 text-[10px] font-bold text-white backdrop-blur-md"
                >
                  <Bike class="mr-1 inline h-3 w-3" />{{ item.bike_type }}
                </span>
              </div>

              <div v-if="authUser && authUser.id === item.author_id" class="flex gap-1.5">
                <button
                  type="button"
                  aria-label="Modifier cette actualité"
                  class="flex h-7 w-7 items-center justify-center rounded-full bg-black/60 text-white transition-colors hover:bg-[#156555]"
                  @click="openEditModal(item)"
                >
                  <Pencil class="h-3.5 w-3.5" />
                </button>
                <button
                  type="button"
                  aria-label="Supprimer cette actualité"
                  class="flex h-7 w-7 items-center justify-center rounded-full bg-black/60 text-white transition-colors hover:bg-red-600"
                  @click="handleDeleteNews(item.id)"
                >
                  <Trash2 class="h-3.5 w-3.5" />
                </button>
              </div>
            </div>
          </div>

          <!-- Corps de la carte -->
          <div class="flex flex-1 flex-col gap-3 p-4 sm:p-5">
            <div class="flex items-center justify-between text-xs text-gray-500">
              <span class="flex items-center gap-1.5">
                <CalendarDays class="h-3.5 w-3.5 text-[#156555]" />
                {{ formatDate(item.created_at) }}
              </span>
              <span v-if="item.author" class="font-semibold text-gray-700">
                {{ item.author.firstname }} {{ item.author.lastname }}
                <em v-if="item.author.level" class="not-italic text-[#156555]">
                  ({{ item.author.level }})
                </em>
              </span>
            </div>

            <h2 class="text-base font-extrabold leading-snug text-gray-900 sm:text-lg">
              {{ item.title }}
            </h2>

            <p v-if="item.summary" class="text-xs font-semibold text-[#661b23]">
              {{ item.summary }}
            </p>

            <p
              :class="[
                'text-xs leading-relaxed text-gray-600 sm:text-sm',
                expandedNewsId === item.id ? 'whitespace-pre-line' : 'line-clamp-3',
              ]"
            >
              {{ item.content }}
            </p>

            <!-- Sortie rattachée facultative -->
            <router-link
              v-if="item.linkedRide"
              :to="{ name: 'ride-detail', params: { id: item.linkedRide.id } }"
              class="mt-1 flex items-center justify-between rounded-xl border border-emerald-900/15 bg-emerald-50/70 px-3 py-2 text-xs font-semibold text-[#156555] transition-colors hover:bg-emerald-100/70"
            >
              <span class="flex items-center gap-1.5 truncate">
                <Link2 class="h-3.5 w-3.5 shrink-0" />
                <span class="truncate">Sortie : {{ item.linkedRide.name }}</span>
              </span>
              <span class="ml-2 shrink-0 font-bold">{{ item.linkedRide.distance }} km</span>
            </router-link>

            <button
              type="button"
              class="mt-auto flex min-h-9 items-center justify-center rounded-xl bg-gray-900 px-3 text-xs font-bold text-white transition-colors hover:bg-[#156555]"
              @click="toggleExpand(item.id)"
            >
              {{ expandedNewsId === item.id ? 'Réduire' : 'Lire la suite' }}
            </button>
          </div>
        </article>
      </div>

      <div v-if="hasMoreNews" class="mt-6 flex justify-center">
        <button
          type="button"
          class="min-h-11 rounded-xl border border-white/15 bg-white/5 px-5 text-sm font-semibold text-white/80 transition-colors hover:bg-white/10"
          @click="visibleLimit += 10"
        >
          Afficher 10 autres actualités
        </button>
      </div>
    </section>

    <!-- Bouton de publication pour membre connecté -->
    <button
      v-if="isAuthenticated"
      type="button"
      class="mx-auto flex min-h-12 w-full max-w-xl items-center justify-center gap-2 rounded-xl bg-[#661b23] px-4 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-red-800"
      @click="openCreateModal"
    >
      <Plus class="h-5 w-5" />
      <span>Publier une actualité</span>
    </button>

    <!-- Modale de création / édition d'actualité -->
    <Teleport to="body">
      <div
        v-if="isModalOpen"
        class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm"
      >
        <div
          class="max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-3xl bg-white p-5 text-gray-900 shadow-2xl sm:p-6"
        >
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-extrabold text-gray-900">
              {{ editingNewsId ? 'Modifier l’actualité' : 'Nouvelle actualité RVC' }}
            </h2>
            <button
              type="button"
              aria-label="Fermer"
              class="rounded-full p-1.5 text-gray-500 hover:bg-gray-100"
              @click="closeModal"
            >
              <X class="h-5 w-5" />
            </button>
          </div>

          <form class="space-y-3.5" @submit.prevent="handleSaveNews">
            <label class="block text-sm font-semibold text-gray-700">
              Titre *
              <input
                v-model="newTitle"
                type="text"
                required
                placeholder="Ex. : Retour sur la randonnée des Herbiers"
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3.5 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-[#156555]"
              />
            </label>

            <div class="grid grid-cols-2 gap-3">
              <label class="block text-sm font-semibold text-gray-700">
                Rubrique *
                <select
                  v-model="newCategory"
                  class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-[#156555]"
                >
                  <option value="Club">Vie du Club</option>
                  <option value="Compétition">Compétition</option>
                  <option value="Événement">Événement</option>
                  <option value="Matériel">Matériel & GPX</option>
                </select>
              </label>

              <label class="block text-sm font-semibold text-gray-700">
                Spécialité vélo
                <select
                  v-model="newBikeType"
                  class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-[#156555]"
                >
                  <option value="">Toutes / Général</option>
                  <option value="Route">Route</option>
                  <option value="Gravel">Gravel</option>
                  <option value="VTT">VTT</option>
                </select>
              </label>
            </div>

            <label class="block text-sm font-semibold text-gray-700">
              Résumé court (affiché dans le bandeau d'accueil)
              <input
                v-model="newSummary"
                type="text"
                placeholder="Une phrase d'accroche..."
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3.5 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-[#156555]"
              />
            </label>

            <label class="block text-sm font-semibold text-gray-700">
              Associer à une sortie existante (facultatif)
              <select
                v-model="newRideId"
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-[#156555]"
              >
                <option value="">Aucune sortie associée</option>
                <option v-for="ride in availableRides" :key="ride.id" :value="ride.id">
                  {{ ride.date }} — {{ ride.name }}
                </option>
              </select>
            </label>

            <!-- Ton composant d'upload d'image intégré à l'identique -->
            <div>
              <label for="ride-image" class="block text-sm font-semibold text-gray-700">
                Image de la sortie / actualité
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
              <div
                v-if="imagePreviewUrl || (currentImageUrl && !shouldRemoveCurrentImage)"
                class="mt-3"
              >
                <img
                  :src="imagePreviewUrl ?? currentImageUrl ?? undefined"
                  alt="Aperçu de l’image de la sortie"
                  class="aspect-video w-full rounded-xl bg-gray-100 object-cover"
                />
                <button
                  type="button"
                  class="mt-2 text-sm font-semibold text-red-700 hover:text-red-800"
                  @click="selectedImage ? removeSelectedImage() : removeCurrentImage()"
                >
                  {{ selectedImage ? 'Annuler le changement' : 'Supprimer l’image actuelle' }}
                </button>
              </div>
              <button
                v-else-if="shouldRemoveCurrentImage"
                type="button"
                class="mt-2 text-sm font-semibold text-gray-700 hover:text-gray-900"
                @click="shouldRemoveCurrentImage = false"
              >
                Annuler la suppression de l’image
              </button>
            </div>

            <label class="block text-sm font-semibold text-gray-700">
              Contenu *
              <textarea
                v-model="newContent"
                rows="4"
                required
                placeholder="Détails de l'actualité, horaires, résultats..."
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-3.5 py-2.5 text-sm text-gray-900 outline-none focus:ring-2 focus:ring-[#156555]"
              ></textarea>
            </label>

            <p v-if="formErrorMessage" role="alert" class="text-xs font-semibold text-red-600">
              {{ formErrorMessage }}
            </p>

            <div class="flex justify-end gap-2 pt-2">
              <button
                type="button"
                class="rounded-xl px-4 py-2.5 text-xs font-bold text-gray-600 hover:bg-gray-100"
                @click="closeModal"
              >
                Annuler
              </button>
              <button
                type="submit"
                :disabled="isSubmitting"
                class="rounded-xl bg-[#156555] px-5 py-2.5 text-xs font-bold text-white transition-colors hover:bg-emerald-800 disabled:opacity-50"
              >
                {{
                  isSubmitting ? 'Enregistrement...' : editingNewsId ? 'Mettre à jour' : 'Publier'
                }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>
  </main>
</template>
