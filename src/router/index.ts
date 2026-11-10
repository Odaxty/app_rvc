import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/views/HomeView.vue'
import { useAuth } from '../composables/useAuth'
import { getSupabaseClient } from '../supabase.ts'

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
      path: '/admin/users',
      name: 'admin-users',
      component: () => import('../views/AdminUsersView.vue'),
      meta: { requiresAdmin: true },
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
      path: '/ride/:id/edit',
      name: 'ride-edit',
      component: () => import('../views/CreateRideView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/auth',
      name: 'auth',
      component: () => import('../views/AuthView.vue'),
    },
    {
      path: '/news/:id',
      name: 'news-detail',
      component: () => import('../views/NewsView.vue'),
    },
    {
      path: '/news',
      name: 'news',
      component: () => import('../views/NewsView.vue'),
    },
  ],
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth && !to.meta.requiresAdmin) return true

  const { user, initializeAuth } = useAuth()
  try {
    await initializeAuth()
  } catch {
    return { name: 'auth', query: { redirect: to.fullPath } }
  }

  if (!user.value) return { name: 'auth', query: { redirect: to.fullPath } }

  if (to.meta.requiresAdmin) {
    const { data, error } = await getSupabaseClient()
      .from('users')
      .select('role, is_active')
      .eq('id', user.value.id)
      .maybeSingle()

    if (error || data?.role !== 'admin' || !data.is_active) return { name: 'profile' }
  }

  return true
})

export default router
