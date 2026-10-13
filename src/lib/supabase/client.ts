import { createBrowserClient } from '@supabase/ssr'
import type { SupabaseClient } from '@supabase/supabase-js'

export function createClient(): SupabaseClient {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

  // Return a mock client if Supabase is not configured
  // This allows development without Supabase credentials
  if (!supabaseUrl || !supabaseKey ||
      supabaseUrl === 'https://your-project-id.supabase.co' ||
      supabaseKey === 'your-publishable-key-here') {
    return {
      auth: {
        getUser: async () => ({ data: { user: null }, error: null }),
        getSession: async () => ({ data: { session: null }, error: null }),
        signInWithPassword: async () => ({ data: { user: null, session: null }, error: { message: 'Supabase not configured' } }),
        signUp: async () => ({ data: { user: null, session: null }, error: { message: 'Supabase not configured' } }),
        signInWithOAuth: async () => ({ data: { provider: null, url: null }, error: { message: 'Supabase not configured' } }),
        signOut: async () => ({ error: null }),
        exchangeCodeForSession: async () => ({ data: { user: null, session: null }, error: { message: 'Supabase not configured' } }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
      },
    } as unknown as SupabaseClient
  }

  return createBrowserClient(supabaseUrl, supabaseKey)
}
