import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../features/auth/AuthProvider'
import type { AppRole } from '../features/auth/authTypes'

export function ProtectedRoute({ allowRoles }: { allowRoles?: AppRole[] }) {
  const { loading, user, profile } = useAuth()
  const location = useLocation()
  if (loading) return <p className="p-6 text-slate-600">Loading your session…</p>
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  if (allowRoles && (!profile || !allowRoles.includes(profile.role))) return <Navigate to="/dashboard" replace />
  return <Outlet />
}

