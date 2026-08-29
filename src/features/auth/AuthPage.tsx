import { useState, type FormEvent, type ReactNode } from 'react'
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from './AuthProvider'

export function LoginPage() {
  const { user, signIn } = useAuth()
  const navigate = useNavigate(); const location = useLocation()
  const [error, setError] = useState<string | null>(null); const [busy, setBusy] = useState(false)
  if (user) return <Navigate to="/dashboard" replace />
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(null)
    const form = new FormData(event.currentTarget)
    const message = await signIn(String(form.get('email')), String(form.get('password')))
    setBusy(false)
    if (message) setError(message); else navigate((location.state as { from?: string } | null)?.from ?? '/dashboard')
  }
  return <AuthCard title="Welcome back" subtitle="Continue building your Class 12 confidence.">
    <form onSubmit={submit} className="space-y-4">
      <Field label="Email" name="email" type="email" autoComplete="email" />
      <Field label="Password" name="password" type="password" autoComplete="current-password" />
      {error && <ErrorMessage message={error} />}
      <button disabled={busy} className="w-full rounded-xl bg-blue-600 px-4 py-3 font-semibold text-white hover:bg-blue-700 disabled:opacity-60">{busy ? 'Signing in…' : 'Sign in'}</button>
    </form>
    <p className="mt-6 text-center text-sm text-slate-600">New here? <Link className="font-semibold text-blue-700" to="/register">Create an account</Link></p>
  </AuthCard>
}

export function RegisterPage() {
  const { user, signUp } = useAuth(); const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null); const [notice, setNotice] = useState<string | null>(null); const [busy, setBusy] = useState(false)
  if (user) return <Navigate to="/dashboard" replace />
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(null); setNotice(null)
    const form = new FormData(event.currentTarget); const password = String(form.get('password'))
    if (password.length < 8) { setError('Use at least 8 characters for your password.'); setBusy(false); return }
    const message = await signUp(String(form.get('name')), String(form.get('email')), password)
    setBusy(false)
    if (message) setNotice(message); else navigate('/dashboard')
  }
  return <AuthCard title="Start your prep" subtitle="Create a free student account in under a minute.">
    <form onSubmit={submit} className="space-y-4">
      <Field label="Name" name="name" autoComplete="name" />
      <Field label="Email" name="email" type="email" autoComplete="email" />
      <Field label="Password" name="password" type="password" autoComplete="new-password" hint="At least 8 characters" />
      {error && <ErrorMessage message={error} />}{notice && <p role="status" className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800">{notice}</p>}
      <button disabled={busy} className="w-full rounded-xl bg-blue-600 px-4 py-3 font-semibold text-white hover:bg-blue-700 disabled:opacity-60">{busy ? 'Creating account…' : 'Create account'}</button>
    </form>
    <p className="mt-6 text-center text-sm text-slate-600">Already have an account? <Link className="font-semibold text-blue-700" to="/login">Sign in</Link></p>
  </AuthCard>
}

function AuthCard({ title, subtitle, children }: { title: string; subtitle: string; children: ReactNode }) {
  return <main className="grid min-h-screen place-items-center bg-gradient-to-br from-blue-50 via-white to-indigo-50 px-4 py-10"><section className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-xl shadow-blue-950/5 sm:p-8"><Link to="/" className="text-sm font-bold text-blue-700">ExamPrep Sprint</Link><h1 className="mt-5 text-3xl font-bold tracking-tight">{title}</h1><p className="mt-2 text-slate-600">{subtitle}</p><div className="mt-7">{children}</div></section></main>
}
function Field({ label, name, type = 'text', autoComplete, hint }: { label: string; name: string; type?: string; autoComplete?: string; hint?: string }) { return <label className="block text-sm font-medium text-slate-700">{label}<input required name={name} type={type} autoComplete={autoComplete} className="mt-1.5 w-full rounded-xl border border-slate-300 px-3 py-2.5 outline-none ring-blue-500 focus:ring-2" />{hint && <span className="mt-1 block text-xs text-slate-500">{hint}</span>}</label> }
function ErrorMessage({ message }: { message: string }) { return <p role="alert" className="rounded-lg bg-rose-50 p-3 text-sm text-rose-800">{message}</p> }

