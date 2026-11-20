<script setup lang="ts">
import { computed } from 'vue'
import { ArrowLeft } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import BottomNav from './components/BottomNav.vue'
import { useTheme } from './composables/useTheme'

const { theme } = useTheme()
const route = useRoute()
const router = useRouter()
const showBackButton = computed(() => route.name !== 'home')

const goBack = () => {
  if (typeof window.history.state?.back === 'string') {
    router.back()
    return
  }

  if (route.name === 'news-detail') {
    void router.replace({ name: 'news' })
  } else if (route.name === 'gpx-detail') {
    void router.replace({ name: 'gpx' })
  } else if (route.name === 'ride-edit' && typeof route.params.id === 'string') {
    void router.replace({ name: 'ride-detail', params: { id: route.params.id } })
  } else {
    void router.replace({ name: 'home' })
  }
}
</script>

<template>
  <main class="app-shell min-h-screen font-sans" :class="`theme-${theme}`">
    <div v-if="showBackButton" class="flex h-14 items-center px-4 sm:px-6">
      <button
        type="button"
        aria-label="Retour à la page précédente"
        title="Retour"
        class="app-back-button flex h-11 w-11 items-center justify-center rounded-full transition-colors hover:bg-white/10"
        @click="goBack"
      >
        <ArrowLeft class="h-6 w-6" />
      </button>
    </div>
    <!-- C'est ici que Vue Router va injecter dynamiquement tes pages (Home, GPX, etc.) -->
    <router-view />

    <BottomNav />
  </main>
</template>
