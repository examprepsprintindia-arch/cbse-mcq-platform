import { Link, NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../features/auth/AuthProvider'

export function AppShell() {
  const { profile, signOut } = useAuth()
  return <div className="min-h-screen">
    <header className="border-b border-slate-200 bg-white/90 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
        <Link to="/dashboard" className="font-bold tracking-tight text-blue-700">ExamPrep <span className="text-slate-900">Sprint</span></Link>
        <nav aria-label="Primary" className="flex items-center gap-1 text-sm font-medium">
          <NavLink to="/dashboard" className={({ isActive }) => `rounded-lg px-3 py-2 ${isActive ? 'bg-blue-50 text-blue-700' : 'text-slate-600 hover:bg-slate-100'}`}>Dashboard</NavLink>
          {profile?.role === 'admin' && <NavLink to="/admin" className={({ isActive }) => `rounded-lg px-3 py-2 ${isActive ? 'bg-blue-50 text-blue-700' : 'text-slate-600 hover:bg-slate-100'}`}>Admin</NavLink>}
          <button onClick={() => void signOut()} className="rounded-lg px-3 py-2 text-slate-600 hover:bg-slate-100">Log out</button>
        </nav>
      </div>
    </header>
    <main className="mx-auto max-w-6xl px-4 py-8 sm:px-6"><Outlet /></main>
  </div>
}

