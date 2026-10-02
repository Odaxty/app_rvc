<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Camera, ChevronRight, Moon, Sun, X } from 'lucide-vue-next'
import { getSupabaseClient } from '../supabase.ts'
import { useAuth } from '../composables/useAuth'
import { useTheme } from '../composables/useTheme'

interface Profile {
  firstname: string
  lastname: string
  email: string
  level: string | null
  avatar_url: string | null
}

const router = useRouter()
const { user: authUser, isAuthenticated, initializeAuth, signOut } = useAuth()
const { theme, setTheme } = useTheme()
const profile = ref<Profile | null>(null)
const rideCount = ref(0)
const gpxCount = ref(0)
const isLoadingProfile = ref(true)
const profileError = ref('')
const isSigningOut = ref(false)
const signOutError = ref('')
const isEditingProfile = ref(false)
const isSavingProfile = ref(false)
const profileSaveError = ref('')
const editFirstname = ref('')
const editLastname = ref('')
const editLevel = ref('')
const selectedAvatar = ref<File | null>(null)
const avatarPreviewUrl = ref('')
const avatarInput = ref<HTMLInputElement | null>(null)
const profileLevels = ['Espoir', 'Sénior', 'Baroudeur']

const initials = computed(() => {
  if (!profile.value) return ''
  return `${profile.value.firstname.charAt(0)}${profile.value.lastname.charAt(0)}`.toUpperCase()
})

const loadProfile = async () => {
  isLoadingProfile.value = true
  profileError.value = ''

  try {
    await initializeAuth()
    if (!authUser.value) return

    const supabase = getSupabaseClient()
    const userId = authUser.value.id
    const [profileResult, ridesResult, gpxResult] = await Promise.all([
      supabase
        .from('users')
        .select('firstname, lastname, email, level, avatar_url')
        .eq('id', userId)
        .maybeSingle(),
      supabase
        .from('ride_participants')
        .select('ride_id', { count: 'exact', head: true })
        .eq('user_id', userId),
      supabase
        .from('gpx_tracks')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId),
    ])

    if (profileResult.error) throw profileResult.error
    if (ridesResult.error) throw ridesResult.error
    if (gpxResult.error) throw gpxResult.error
    if (!profileResult.data) {
      throw new Error(
        'Profil introuvable. Vérifie que le trigger de création du profil a fonctionné.',
      )
    }

    profile.value = profileResult.data
    rideCount.value = ridesResult.count ?? 0
    gpxCount.value = gpxResult.count ?? 0
  } catch (error) {
    profileError.value = error instanceof Error ? error.message : 'Impossible de charger le profil.'
  } finally {
    isLoadingProfile.value = false
  }
}

onMounted(() => void loadProfile())

const clearAvatarPreview = () => {
  if (avatarPreviewUrl.value) URL.revokeObjectURL(avatarPreviewUrl.value)
  avatarPreviewUrl.value = ''
}

onBeforeUnmount(clearAvatarPreview)

const openProfileEditor = () => {
  if (!profile.value) return
  editFirstname.value = profile.value.firstname
  editLastname.value = profile.value.lastname
  editLevel.value = profile.value.level ?? ''
  selectedAvatar.value = null
  clearAvatarPreview()
  profileSaveError.value = ''
  isEditingProfile.value = true
}

const handleAvatarChange = (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0] ?? null
  profileSaveError.value = ''
  clearAvatarPreview()
  selectedAvatar.value = null

  if (!file) return
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
    profileSaveError.value = 'Choisis une image JPG, PNG ou WebP.'
    input.value = ''
    return
  }
  if (file.size > 5 * 1024 * 1024) {
    profileSaveError.value = 'La photo ne doit pas dépasser 5 Mo.'
    input.value = ''
    return
  }

  selectedAvatar.value = file
  avatarPreviewUrl.value = URL.createObjectURL(file)
}

const saveProfile = async () => {
  if (!authUser.value || !profile.value) return

  const firstname = editFirstname.value.trim()
  const lastname = editLastname.value.trim()
  if (!firstname || !lastname) {
    profileSaveError.value = 'Le prénom et le nom sont obligatoires.'
    return
  }

  isSavingProfile.value = true
  profileSaveError.value = ''

  try {
    const supabase = getSupabaseClient()
    let avatarUrl = profile.value.avatar_url

    if (selectedAvatar.value) {
      const { error: uploadError } = await supabase.storage
        .from('user-images')
        .upload(`${authUser.value.id}/avatar`, selectedAvatar.value, {
          cacheControl: '0',
          contentType: selectedAvatar.value.type,
          upsert: true,
        })

      if (uploadError) throw uploadError
      avatarUrl = supabase.storage.from('user-images').getPublicUrl(`${authUser.value.id}/avatar`)
        .data.publicUrl
    }

    const { error } = await supabase
      .from('users')
      .update({ firstname, lastname, level: editLevel.value || null, avatar_url: avatarUrl })
      .eq('id', authUser.value.id)

    if (error) throw error
    profile.value = {
      ...profile.value,
      firstname,
      lastname,
      level: editLevel.value || null,
      avatar_url: avatarUrl,
    }
    isEditingProfile.value = false
    selectedAvatar.value = null
    clearAvatarPreview()
  } catch (error) {
    profileSaveError.value =
      error instanceof Error ? error.message : 'Impossible d’enregistrer le profil.'
  } finally {
    isSavingProfile.value = false
  }
}

const handleSignOut = async () => {
  isSigningOut.value = true
  signOutError.value = ''

  try {
    await signOut()
    await router.replace('/auth')
  } catch (error) {
    signOutError.value = error instanceof Error ? error.message : 'Impossible de se déconnecter.'
  } finally {
    isSigningOut.value = false
  }
}
</script>

<template>
  <div class="account-page min-h-screen px-4 pb-28 pt-7 sm:px-6">
    <p v-if="isLoadingProfile" class="mx-auto max-w-3xl py-8 text-center text-sm text-gray-500">
      Chargement du profil...
    </p>
    <p
      v-else-if="profileError"
      role="alert"
      class="mx-auto max-w-3xl rounded-xl bg-red-50 p-3 text-sm text-red-700"
    >
      {{ profileError }}
    </p>
    <div v-else-if="!profile" class="mx-auto max-w-3xl py-8 text-center">
      <p class="mb-4 text-gray-300">Connecte-toi pour consulter ton compte.</p>
      <router-link to="/auth" class="font-semibold text-green-700">Se connecter</router-link>
    </div>

    <template v-else>
      <div class="mx-auto max-w-3xl">
        <h1 class="mb-4 text-2xl font-bold text-white">Mon compte</h1>
        <section
          class="account-card flex flex-col items-center rounded-3xl p-6 shadow-xl sm:flex-row sm:gap-6 sm:p-7"
        >
          <div
            class="mb-4 flex h-24 w-24 shrink-0 items-center justify-center overflow-hidden rounded-full bg-red-600 ring-4 ring-white/10 sm:mb-0"
          >
            <img
              v-if="profile.avatar_url"
              :src="profile.avatar_url"
              :alt="`Photo de ${profile.firstname} ${profile.lastname}`"
              class="h-full w-full rounded-full object-cover"
            />
            <span v-else class="text-2xl font-bold text-black">{{ initials }}</span>
          </div>

          <div class="text-center sm:flex-1 sm:text-left">
            <h2 class="text-2xl font-bold text-gray-900">
              {{ profile.firstname }} {{ profile.lastname }}
            </h2>
            <p class="mt-1 text-gray-500">{{ profile.email }}</p>

            <span
              v-if="profile.level"
              class="mt-3 inline-flex rounded-full bg-green-100 px-3 py-1 text-sm font-semibold text-green-700"
            >
              {{ profile.level }}
            </span>
          </div>
        </section>

        <div class="mt-4 grid grid-cols-2 gap-3 sm:gap-4">
          <div
            class="account-card flex flex-col items-center justify-center rounded-2xl p-5 text-center sm:p-6"
          >
            <span class="text-3xl font-bold text-gray-900">{{ rideCount }}</span>
            <span class="mt-1 text-sm font-semibold text-gray-500">Sorties</span>
          </div>

          <div
            class="account-card flex flex-col items-center justify-center rounded-2xl p-5 text-center sm:p-6"
          >
            <span class="text-3xl font-bold text-red-600">{{ gpxCount }}</span>
            <span class="mt-1 text-sm font-semibold text-gray-500">GPX partagés</span>
          </div>
        </div>

        <section
          class="account-card mt-4 rounded-2xl p-5 sm:flex sm:items-center sm:justify-between sm:gap-5"
        >
          <div>
            <h2 class="font-bold text-gray-900">Apparence</h2>
            <p class="mt-1 text-sm text-gray-500">Choisis ton thème pour l’application.</p>
          </div>
          <div
            class="account-theme-switch mt-4 grid grid-cols-2 gap-1 rounded-xl p-1 sm:mt-0 sm:w-64"
          >
            <button
              type="button"
              :aria-pressed="theme === 'light'"
              class="account-theme-option"
              :class="{ 'is-selected': theme === 'light' }"
              @click="setTheme('light')"
            >
              <Sun class="h-4 w-4" />
              Clair
            </button>
            <button
              type="button"
              :aria-pressed="theme === 'dark'"
              class="account-theme-option"
              :class="{ 'is-selected': theme === 'dark' }"
              @click="setTheme('dark')"
            >
              <Moon class="h-4 w-4" />
              Sombre
            </button>
          </div>
        </section>

        <div class="account-card mt-4 flex flex-col overflow-hidden rounded-2xl">
          <button
            type="button"
            @click="openProfileEditor"
            class="w-full flex justify-between items-center p-5 text-left border-b border-gray-50 hover:bg-gray-50 transition-colors"
          >
            <span class="font-bold text-gray-900 text-lg">Modifier profil</span>
            <ChevronRight class="w-5 h-5 text-gray-400" />
          </button>

          <!-- Bouton Mes GPXs -->
          <router-link
            :to="{ name: 'gpx', query: { mine: '1' } }"
            class="w-full flex justify-between items-center p-5 text-left border-b border-gray-50 hover:bg-gray-50 transition-colors"
          >
            <span class="font-bold text-gray-900 text-lg">Mes GPXs</span>
            <ChevronRight class="w-5 h-5 text-gray-400" />
          </router-link>

          <p v-if="signOutError" role="alert" class="p-4 text-sm text-red-700">
            {{ signOutError }}
          </p>

          <button
            v-if="isAuthenticated"
            @click="handleSignOut"
            :disabled="isSigningOut"
            class="w-full flex justify-start items-center p-5 text-left hover:bg-gray-50 transition-colors"
          >
            <span class="font-bold text-red-600 text-lg">
              {{ isSigningOut ? 'Déconnexion...' : 'Déconnexion' }}
            </span>
          </button>
          <router-link
            v-else
            to="/auth"
            class="w-full p-5 text-left font-bold text-green-700 text-lg hover:bg-gray-50 transition-colors"
          >
            Se connecter
          </router-link>
        </div>
      </div>

      <div
        v-if="isEditingProfile"
        class="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-4"
        @click.self="isEditingProfile = false"
      >
        <form
          class="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-t-3xl bg-white p-6 shadow-xl sm:rounded-3xl"
          @submit.prevent="saveProfile"
        >
          <div class="mb-5 flex items-center justify-between">
            <h2 class="text-xl font-bold text-gray-900">Modifier le profil</h2>
            <button
              type="button"
              aria-label="Fermer"
              class="flex h-10 w-10 items-center justify-center rounded-full text-gray-600 hover:bg-gray-100"
              @click="isEditingProfile = false"
            >
              <X class="h-5 w-5" />
            </button>
          </div>

          <div class="mb-5 flex items-center gap-4">
            <div
              class="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-gray-100"
            >
              <img
                v-if="avatarPreviewUrl || profile.avatar_url"
                :src="avatarPreviewUrl || profile.avatar_url || ''"
                alt="Aperçu de la photo de profil"
                class="h-full w-full object-cover"
              />
              <span v-else class="font-bold text-gray-600">{{ initials }}</span>
            </div>
            <input
              ref="avatarInput"
              type="file"
              accept="image/jpeg,image/png,image/webp"
              class="sr-only"
              @change="handleAvatarChange"
            />
            <button
              type="button"
              class="inline-flex min-h-10 items-center gap-2 rounded-lg border border-gray-200 px-3 text-sm font-semibold text-gray-800 hover:bg-gray-50"
              @click="avatarInput?.click()"
            >
              <Camera class="h-4 w-4" />
              Changer la photo
            </button>
          </div>

          <div class="space-y-4">
            <label class="block text-sm font-semibold text-gray-700">
              Prénom
              <input
                v-model="editFirstname"
                type="text"
                required
                maxlength="80"
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
              />
            </label>
            <label class="block text-sm font-semibold text-gray-700">
              Nom
              <input
                v-model="editLastname"
                type="text"
                required
                maxlength="80"
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
              />
            </label>
            <label class="block text-sm font-semibold text-gray-700">
              Niveau
              <select
                v-model="editLevel"
                class="mt-1 w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
              >
                <option value="">Non renseigné</option>
                <option v-for="level in profileLevels" :key="level" :value="level">
                  {{ level }}
                </option>
              </select>
            </label>
          </div>

          <p v-if="profileSaveError" role="alert" class="mt-4 text-sm text-red-700">
            {{ profileSaveError }}
          </p>
          <div class="mt-6 flex gap-3">
            <button
              type="button"
              class="min-h-11 flex-1 rounded-xl border border-gray-200 font-semibold text-gray-700 hover:bg-gray-50"
              @click="isEditingProfile = false"
            >
              Annuler
            </button>
            <button
              type="submit"
              :disabled="isSavingProfile"
              class="min-h-11 flex-1 rounded-xl bg-green-600 font-semibold text-white hover:bg-green-700 disabled:opacity-50"
            >
              {{ isSavingProfile ? 'Enregistrement...' : 'Enregistrer' }}
            </button>
          </div>
        </form>
      </div>
    </template>
  </div>
</template>
