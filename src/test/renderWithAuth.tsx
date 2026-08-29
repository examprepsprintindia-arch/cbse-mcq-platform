import { type ReactNode } from 'react'
import { MemoryRouter } from 'react-router-dom'
import { AuthContext } from '../features/auth/AuthProvider'
import type { AuthState, Profile } from '../features/auth/authTypes'

export function renderWithAuthState(children: ReactNode, state: Partial<AuthState> = {}, entries = ['/']) {
  const value = {
    session: null, user: null, profile: null, loading: false, error: null,
    signIn: async () => null, signUp: async () => null, signOut: async () => {},
    ...state,
  }
  return <MemoryRouter initialEntries={entries}><AuthContext.Provider value={value}>{children}</AuthContext.Provider></MemoryRouter>
}

export const studentProfile: Profile = { id: 'student-1', full_name: 'Aarav Sharma', role: 'student' }
export const adminProfile: Profile = { id: 'admin-1', full_name: 'Admin User', role: 'admin' }

