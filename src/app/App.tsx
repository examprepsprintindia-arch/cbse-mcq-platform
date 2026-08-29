import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/AppShell'
import { ProtectedRoute } from '../components/RouteGuards'
import { AdminPage } from '../features/admin/AdminPage'
import { LoginPage, RegisterPage } from '../features/auth/AuthPage'
import { DashboardPage } from '../features/dashboard/DashboardPage'

function LandingPage() { return <main className="grid min-h-screen place-items-center bg-slate-50 p-6 text-center"><div><p className="font-bold text-blue-700">ExamPrep Sprint</p><h1 className="mt-2 text-4xl font-bold tracking-tight">Focused Class 12 practice.</h1><p className="mt-3 text-slate-600">A calm, secure space to prepare one question at a time.</p><a className="mt-6 inline-block rounded-xl bg-blue-600 px-5 py-3 font-semibold text-white" href="/register">Create your account</a></div></main> }

export function App() { return <Routes>
  <Route path="/" element={<LandingPage />} />
  <Route path="/login" element={<LoginPage />} />
  <Route path="/register" element={<RegisterPage />} />
  <Route element={<ProtectedRoute />}><Route element={<AppShell />}><Route path="/dashboard" element={<DashboardPage />} /></Route></Route>
  <Route element={<ProtectedRoute allowRoles={['admin']} />}><Route element={<AppShell />}><Route path="/admin" element={<AdminPage />} /></Route></Route>
  <Route path="*" element={<Navigate to="/" replace />} />
</Routes> }

