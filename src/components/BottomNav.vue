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
        class="bottom-nav-link"
        :class="{ 'is-active': route.name === 'gpx' }"
      >
        <Map class="h-5 w-5" />
        <span>Parcours</span>
      </router-link>

      <router-link
        to="/"
        aria-label="Accueil, sorties"
        class="bottom-nav-link"
        :class="{ 'is-active': route.name === 'home' }"
      >
        <Home class="h-5 w-5" />
        <span>Sorties</span>
      </router-link>

      <router-link
        to="/profile"
        aria-label="Mon profil"
        class="bottom-nav-link"
        :class="{ 'is-active': route.name === 'profile' }"
      >
        <User class="h-5 w-5" />
        <span>Mon compte</span>
      </router-link>
    </div>
    <p class="bottom-nav-credit pb-2 text-center text-[11px]">
      Réalisé par
      <a
        href="https://theo.chauviere.eu/"
        target="_blank"
        rel="noopener noreferrer"
        class="bottom-nav-credit-link font-semibold underline-offset-2 hover:underline"
      >
        DevWebTheo
      </a>
    </p>
  </nav>
</template>
