import { render, screen } from '@testing-library/react'
import { Route, Routes } from 'react-router-dom'
import { describe, expect, it } from 'vitest'
import { ProtectedRoute } from './RouteGuards'
import { renderWithAuthState, studentProfile } from '../test/renderWithAuth'

describe('ProtectedRoute', () => {
  it('redirects unauthenticated users to login', () => {
    render(renderWithAuthState(<Routes><Route element={<ProtectedRoute />}><Route path="/dashboard" element={<p>Dashboard</p>} /></Route><Route path="/login" element={<p>Login</p>} /></Routes>, {}, ['/dashboard']))
    expect(screen.getByText('Login')).toBeInTheDocument()
  })
  it('allows an authenticated student into the dashboard', () => {
    render(renderWithAuthState(<Routes><Route element={<ProtectedRoute />}><Route path="/dashboard" element={<p>Dashboard</p>} /></Route></Routes>, { user: { id: 'student-1' } as never, profile: studentProfile }, ['/dashboard']))
    expect(screen.getByText('Dashboard')).toBeInTheDocument()
  })
  it('redirects a student away from the admin route', () => {
    render(renderWithAuthState(<Routes><Route element={<ProtectedRoute allowRoles={['admin']} />}><Route path="/admin" element={<p>Admin</p>} /></Route><Route path="/dashboard" element={<p>Dashboard</p>} /></Routes>, { user: { id: 'student-1' } as never, profile: studentProfile }, ['/admin']))
    expect(screen.getByText('Dashboard')).toBeInTheDocument()
  })
})

