import { computed, readonly, ref } from 'vue'
import type { User } from '@supabase/supabase-js'
import { getSupabaseClient } from '../supabase.ts'

const currentUser = ref<User | null>(null)
const isAuthReady = ref(false)
let initialization: Promise<void> | null = null

export function useAuth() {
  const initializeAuth = (): Promise<void> => {
    if (!initialization) {
      initialization = (async () => {
        const supabase = getSupabaseClient()
        supabase.auth.onAuthStateChange((_event, session) => {
          currentUser.value = session?.user ?? null
          isAuthReady.value = true
        })

        const { data, error } = await supabase.auth.getSession()
        if (error) throw error

        currentUser.value = data.session?.user ?? null
        isAuthReady.value = true
      })().catch((error: unknown) => {
        initialization = null
        throw error
      })
    }

    return initialization
  }

  const signOut = async (): Promise<void> => {
    const { error } = await getSupabaseClient().auth.signOut()
    if (error) throw error

    currentUser.value = null
  }

  return {
    user: readonly(currentUser),
    isAuthenticated: computed(() => currentUser.value !== null),
    isAuthReady: readonly(isAuthReady),
    initializeAuth,
    signOut,
  }
}
