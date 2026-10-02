<script setup lang="ts">
import BottomNav from './components/BottomNav.vue'
import { useTheme } from './composables/useTheme'

const { theme } = useTheme()
</script>

<template>
  <main class="app-shell min-h-screen font-sans" :class="`theme-${theme}`">
    <!-- C'est ici que Vue Router va injecter dynamiquement tes pages (Home, GPX, etc.) -->
    <router-view />

    <BottomNav />
  </main>
</template>
