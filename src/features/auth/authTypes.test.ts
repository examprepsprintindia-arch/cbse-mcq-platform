import '@testing-library/jest-dom/vitest'
import { describe, expect, it } from 'vitest'
import { authReducer, initialAuthState } from './authTypes'

describe('authentication state', () => {
  it('clears the profile when a session expires', () => {
    const state = { ...initialAuthState, loading: false, profile: { id: 'u1', full_name: 'Aarav', role: 'student' as const } }
    expect(authReducer(state, { type: 'SESSION', session: null })).toMatchObject({ user: null, profile: null, session: null })
  })
})

