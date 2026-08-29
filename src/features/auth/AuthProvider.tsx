import { createContext, useContext, useEffect, useMemo, useReducer, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '../../integrations/supabase/client'
import { authReducer, initialAuthState, type AppRole, type AuthState, type Profile } from './authTypes'

interface AuthContextValue extends AuthState {
  signIn(email: string, password: string): Promise<string | null>
  signUp(name: string, email: string, password: string): Promise<string | null>
  signOut(): Promise<void>
}

export const AuthContext = createContext<AuthContextValue | null>(null)

async function getProfile(userId: string): Promise<Profile | null> {
  if (!supabase) return null
  const { data, error } = await supabase.from('profiles').select('id, full_name, role').eq('id', userId).maybeSingle()
  if (error) throw error
  return data as Profile | null
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(authReducer, initialAuthState)

  useEffect(() => {
    let active = true
    async function loadSession(session: Session | null) {
      dispatch({ type: 'SESSION', session })
      try {
        dispatch({ type: 'PROFILE', profile: session ? await getProfile(session.user.id) : null })
        dispatch({ type: 'ERROR', error: null })
      } catch {
        dispatch({ type: 'PROFILE', profile: null })
        dispatch({ type: 'ERROR', error: 'We could not load your profile. Please try again.' })
      } finally {
        if (active) dispatch({ type: 'LOADING', loading: false })
      }
    }

    if (!supabase) {
      dispatch({ type: 'LOADING', loading: false })
      dispatch({ type: 'ERROR', error: 'Authentication is not configured for this environment.' })
      return
    }

    void supabase.auth.getSession().then(({ data }) => loadSession(data.session))
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => { void loadSession(session) })
    return () => { active = false; listener.subscription.unsubscribe() }
  }, [])

  const value = useMemo<AuthContextValue>(() => ({
    ...state,
    async signIn(email, password) {
      if (!supabase) return 'Authentication is not configured for this environment.'
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      return error?.message ?? null
    },
    async signUp(name, email, password) {
      if (!supabase) return 'Authentication is not configured for this environment.'
      const { data, error } = await supabase.auth.signUp({ email, password, options: { data: { full_name: name.trim() } } })
      if (error) return error.message
      // The database trigger creates profiles. Confirmation-enabled projects return no session here.
      return data.session ? null : 'Check your email to confirm your account, then sign in.'
    },
    async signOut() { if (supabase) await supabase.auth.signOut() },
  }), [state])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) throw new Error('useAuth must be used within AuthProvider')
  return context
}

export type { AppRole }

