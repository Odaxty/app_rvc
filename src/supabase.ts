import { createClient, type SupabaseClient } from '@supabase/supabase-js'

let supabaseClient: SupabaseClient | undefined

export function getSupabaseClient(): SupabaseClient {
  if (supabaseClient) {
    return supabaseClient
  }

  const { VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY } = import.meta.env

  if (!VITE_SUPABASE_URL || !VITE_SUPABASE_ANON_KEY) {
    throw new Error('Configure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in .env.local.')
  }

  supabaseClient = createClient(VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY)
  return supabaseClient
}
