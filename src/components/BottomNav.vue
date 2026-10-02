<script setup lang="ts">
import { Home, Map, User } from 'lucide-vue-next'
import { useRoute } from 'vue-router'

const route = useRoute()
</script>

<template>
  <nav class="glass-nav fixed bottom-0 left-0 right-0 z-50">
    <div class="mx-auto flex h-16 max-w-xl items-center justify-around">
      <router-link
        to="/gpx"
        aria-label="Parcours GPX"
        class="flex h-12 w-14 items-center justify-center rounded-2xl transition-colors"
        :class="
          route.name === 'gpx' ? 'bg-white/10 text-emerald-300' : 'text-white/55 hover:text-white'
        "
      >
        <Map class="h-5 w-5" />
      </router-link>

      <router-link
        to="/"
        aria-label="Accueil, sorties"
        class="flex h-12 w-14 items-center justify-center rounded-2xl transition-colors"
        :class="
          route.name === 'home' ? 'bg-white/10 text-emerald-300' : 'text-white/55 hover:text-white'
        "
      >
        <Home class="h-5 w-5" />
      </router-link>

      <router-link
        to="/profile"
        aria-label="Mon profil"
        class="flex h-12 w-14 items-center justify-center rounded-2xl transition-colors"
        :class="
          route.name === 'profile'
            ? 'bg-white/10 text-emerald-300'
            : 'text-white/55 hover:text-white'
        "
      >
        <User class="h-5 w-5" />
      </router-link>
    </div>
    <p class="pb-2 text-center text-[11px] text-white/50">
      Réalisé par
      <a
        href="https://theo.chauviere.eu/"
        target="_blank"
        rel="noopener noreferrer"
        class="font-semibold text-white/75 underline-offset-2 hover:underline"
      >
        DevWebTheo
      </a>
    </p>
  </nav>
</template>
