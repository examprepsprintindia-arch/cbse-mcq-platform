import type { Session, User } from '@supabase/supabase-js'

export type AppRole = 'student' | 'admin'

export interface Profile {
  id: string
  full_name: string | null
  role: AppRole
}

export interface AuthState {
  session: Session | null
  user: User | null
  profile: Profile | null
  loading: boolean
  error: string | null
}

export const initialAuthState: AuthState = {
  session: null,
  user: null,
  profile: null,
  loading: true,
  error: null,
}

export type AuthAction =
  | { type: 'SESSION'; session: Session | null }
  | { type: 'PROFILE'; profile: Profile | null }
  | { type: 'LOADING'; loading: boolean }
  | { type: 'ERROR'; error: string | null }

export function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case 'SESSION':
      return { ...state, session: action.session, user: action.session?.user ?? null, profile: action.session ? state.profile : null }
    case 'PROFILE':
      return { ...state, profile: action.profile }
    case 'LOADING':
      return { ...state, loading: action.loading }
    case 'ERROR':
      return { ...state, error: action.error }
  }
}

