import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const isSupabaseConfigured = Boolean(url && anonKey)

// This client deliberately uses only the browser-safe anonymous key. Service-role
// credentials are never available to a Vite build.
export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(url ?? '', anonKey ?? '', {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
  : null

