import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/views/HomeView.vue'
import { useAuth } from '../composables/useAuth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      // Le chemin '/' correspond à la racine de ton site (l'accueil)
      path: '/',
      name: 'home',
      component: HomeView,
    },

    {
      path: '/gpx',
      name: 'gpx',
      component: () => import('../views/GpxView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/gpx/:id',
      name: 'gpx-detail',
      component: () => import('../views/GpxDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/profile',
      name: 'profile',
      component: () => import('../views/ProfileView.vue'),
    },
    {
      path: '/ride/:id',
      name: 'ride-detail',
      component: () => import('../views/RideDetailView.vue'),
    },
    {
      path: '/ride/new',
      name: 'ride-create',
      component: () => import('../views/CreateRideView.vue'),
    },
    {
      path: '/auth',
      name: 'auth',
      component: () => import('../views/AuthView.vue'),
    },
  ],
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return true

  const { user, initializeAuth } = useAuth()
  try {
    await initializeAuth()
  } catch {
    return { name: 'auth', query: { redirect: to.fullPath } }
  }

  return user.value ? true : { name: 'auth', query: { redirect: to.fullPath } }
})

export default router
