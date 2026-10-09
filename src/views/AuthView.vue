<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Eye, EyeOff } from 'lucide-vue-next'
import { getSupabaseClient } from '../supabase.ts'

const router = useRouter()
const route = useRoute()

// États de l'interface
const isLogin = ref(true)
const isResetRequest = ref(false)
const isPasswordRecovery = computed(() => route.query.mode === 'update-password')
const isLoading = ref(false)
const errorMessage = ref('')
const successMessage = ref('')
const isPasswordVisible = ref(false)
let redirectTimeout: ReturnType<typeof setTimeout> | undefined

onBeforeUnmount(() => {
  if (redirectTimeout) clearTimeout(redirectTimeout)
})

// Données du formulaire
const email = ref('')
const password = ref('')
const firstname = ref('')
const lastname = ref('')

const showPasswordReset = () => {
  isResetRequest.value = true
  errorMessage.value = ''
  successMessage.value = ''
}

const showLogin = () => {
  isResetRequest.value = false
  errorMessage.value = ''
  successMessage.value = ''
}

// Fonction principale d'authentification
const handleAuth = async () => {
  try {
    isLoading.value = true
    errorMessage.value = ''
    successMessage.value = ''

    if (isPasswordRecovery.value) {
      const { error } = await getSupabaseClient().auth.updateUser({
        password: password.value,
      })
      if (error) throw error

      password.value = ''
      await router.replace({ name: 'auth' })
      successMessage.value = 'Mot de passe modifié. Vous pouvez vous connecter.'
    } else if (isResetRequest.value) {
      const redirectTo = new URL(
        `${import.meta.env.BASE_URL}auth?mode=update-password`,
        window.location.origin,
      ).toString()
      const { error } = await getSupabaseClient().auth.resetPasswordForEmail(email.value, {
        redirectTo,
      })
      if (error) throw error

      successMessage.value =
        'Si un compte correspond à cette adresse, un e-mail de réinitialisation vient d’être envoyé.'
    } else if (isLogin.value) {
      // Logique de Connexion
      const { error } = await getSupabaseClient().auth.signInWithPassword({
        email: email.value,
        password: password.value,
      })
      if (error) throw error

      // Redirection vers l'accueil après connexion
      const redirectTarget = route.query.redirect
      const destination =
        typeof redirectTarget === 'string' &&
        redirectTarget.startsWith('/') &&
        !redirectTarget.startsWith('//')
          ? redirectTarget
          : '/'
      await router.replace(destination)
    } else {
      // Logique d'Inscription
      const { error } = await getSupabaseClient().auth.signUp({
        email: email.value,
        password: password.value,
        options: {
          // On passe le prénom et nom dans les métadonnées pour pouvoir les insérer
          // dans ta table public.users par la suite (idéalement via un Trigger SQL)
          data: {
            firstname: firstname.value,
            lastname: lastname.value,
          },
        },
      })
      if (error) throw error

      successMessage.value = 'Compte créé. Veuillez vous connecter.'
      redirectTimeout = setTimeout(() => {
        isLogin.value = true
        router.replace('/auth')
      }, 5000)
    }
  } catch (error: unknown) {
    errorMessage.value = error instanceof Error ? error.message : 'Une erreur est survenue.'
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 flex flex-col justify-center px-4 pb-20">
    <!-- En-tête -->
    <div class="text-center mb-8">
      <div
        class="w-16 h-16 bg-red-600 rounded-3xl mx-auto flex items-center justify-center shadow-sm mb-4"
      >
        <span class="text-2xl font-bold text-black">RVC</span>
      </div>
      <h1 class="text-3xl font-bold text-white">Roche Vendée Cyclisme</h1>
      <p class="mt-2 text-white/60">Rejoignez le peloton</p>
    </div>

    <!-- Carte Bento du Formulaire -->
    <div
      class="surface-card bg-white rounded-3xl shadow-sm p-6 border border-gray-50 max-w-md w-full mx-auto"
    >
      <h2 v-if="isPasswordRecovery" class="mb-6 text-xl font-bold text-gray-900">
        Choisir un nouveau mot de passe
      </h2>
      <h2 v-else-if="isResetRequest" class="mb-6 text-xl font-bold text-gray-900">
        Réinitialiser le mot de passe
      </h2>

      <!-- Onglets (Tabs) -->
      <div
        v-if="!isPasswordRecovery && !isResetRequest"
        class="flex bg-gray-100 p-1 rounded-2xl mb-6"
      >
        <button
          type="button"
          @click="isLogin = true"
          class="flex-1 py-2 rounded-xl text-sm font-bold transition-all"
          :class="isLogin ? 'bg-white text-black shadow-sm' : 'text-gray-500 hover:text-gray-700'"
        >
          Connexion
        </button>
        <button
          type="button"
          @click="isLogin = false"
          class="flex-1 py-2 rounded-xl text-sm font-bold transition-all"
          :class="!isLogin ? 'bg-white text-black shadow-sm' : 'text-gray-500 hover:text-gray-700'"
        >
          Inscription
        </button>
      </div>

      <!-- Message d'erreur -->
      <div
        v-if="errorMessage"
        class="bg-red-50 text-red-600 p-3 rounded-xl text-sm mb-4 font-medium"
      >
        {{ errorMessage }}
      </div>
      <div
        v-if="successMessage"
        role="status"
        class="bg-green-50 text-green-700 p-3 rounded-xl text-sm mb-4 font-medium"
      >
        {{ successMessage }}
      </div>

      <!-- Formulaire -->
      <form @submit.prevent="handleAuth" class="space-y-4">
        <!-- Champs spécifiques à l'inscription -->
        <div v-if="!isLogin && !isResetRequest && !isPasswordRecovery" class="flex gap-4">
          <div class="flex-1">
            <label class="block text-sm font-semibold text-gray-700 mb-1">Prénom</label>
            <input
              v-model="firstname"
              type="text"
              required
              class="w-full bg-gray-50 border border-gray-100 rounded-xl py-3 px-4 outline-none focus:ring-2 focus:ring-red-500 transition-all"
            />
          </div>
          <div class="flex-1">
            <label class="block text-sm font-semibold text-gray-700 mb-1">Nom</label>
            <input
              v-model="lastname"
              type="text"
              required
              class="w-full bg-gray-50 border border-gray-100 rounded-xl py-3 px-4 outline-none focus:ring-2 focus:ring-red-500 transition-all"
            />
          </div>
        </div>

        <!-- Email -->
        <div v-if="!isPasswordRecovery">
          <label class="block text-sm font-semibold text-gray-700 mb-1">Email</label>
          <input
            v-model="email"
            type="email"
            required
            placeholder="theo.chauviere@email.com"
            class="w-full bg-gray-50 border border-gray-100 rounded-xl py-3 px-4 outline-none focus:ring-2 focus:ring-red-500 transition-all"
          />
        </div>

        <!-- Mot de passe -->
        <div v-if="!isResetRequest || isPasswordRecovery">
          <label for="auth-password" class="mb-1 block text-sm font-semibold text-gray-700">
            Mot de passe
          </label>
          <div class="relative">
            <input
              id="auth-password"
              v-model="password"
              :type="isPasswordVisible ? 'text' : 'password'"
              required
              :autocomplete="isPasswordRecovery ? 'new-password' : 'current-password'"
              class="w-full rounded-xl border border-gray-100 bg-gray-50 py-3 pl-4 pr-12 outline-none transition-all focus:ring-2 focus:ring-red-500"
            />
            <button
              type="button"
              :aria-label="
                isPasswordVisible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'
              "
              :aria-pressed="isPasswordVisible"
              class="absolute inset-y-0 right-0 flex w-12 items-center justify-center text-gray-500 hover:text-gray-800"
              @click="isPasswordVisible = !isPasswordVisible"
            >
              <EyeOff v-if="isPasswordVisible" class="h-5 w-5" />
              <Eye v-else class="h-5 w-5" />
            </button>
          </div>
        </div>

        <!-- Bouton de soumission -->
        <button
          type="submit"
          :disabled="isLoading"
          class="w-full mt-2 bg-green-500 text-white font-bold py-3.5 rounded-xl hover:bg-green-600 transition-colors disabled:opacity-50 flex justify-center"
        >
          <span v-if="isLoading">Chargement...</span>
          <span v-else-if="isPasswordRecovery">Modifier mon mot de passe</span>
          <span v-else-if="isResetRequest">Envoyer le lien</span>
          <span v-else>{{ isLogin ? 'Se connecter' : 'Créer mon compte' }}</span>
        </button>
      </form>

      <button
        v-if="isLogin && !isResetRequest && !isPasswordRecovery"
        type="button"
        class="mt-4 w-full text-sm font-semibold text-green-700 hover:text-green-800"
        @click="showPasswordReset"
      >
        Mot de passe oublié ?
      </button>
      <button
        v-if="isResetRequest"
        type="button"
        class="mt-4 w-full text-sm font-semibold text-gray-600 hover:text-gray-800"
        @click="showLogin"
      >
        Retour à la connexion
      </button>
    </div>
  </div>
</template>
