import '@testing-library/jest-dom/vitest'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { AppShell } from './AppShell'
import { renderWithAuthState, adminProfile, studentProfile } from '../test/renderWithAuth'

describe('role-aware navigation', () => {
  it('does not show the admin link to students', () => {
    render(renderWithAuthState(<AppShell />, { user: { id: 'student-1' } as never, profile: studentProfile }))
    expect(screen.queryByRole('link', { name: 'Admin' })).not.toBeInTheDocument()
  })
  it('shows the admin link to admins', () => {
    render(renderWithAuthState(<AppShell />, { user: { id: 'admin-1' } as never, profile: adminProfile }))
    expect(screen.getByRole('link', { name: 'Admin' })).toBeInTheDocument()
  })
})

