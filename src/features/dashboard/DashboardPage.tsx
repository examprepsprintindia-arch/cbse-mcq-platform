import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../../integrations/supabase/client'
import { useAuth } from '../auth/AuthProvider'
import { fetchDashboardData, formatDuration, getProgressSummary, type DashboardData, type RecentAttempt } from './dashboardData'

type DashboardState = { kind: 'loading' } | { kind: 'error'; message: string } | { kind: 'ready'; data: DashboardData }

export function DashboardPage() {
  const { profile } = useAuth()
  const [state, setState] = useState<DashboardState>({ kind: 'loading' })
  const load = useCallback(async () => {
    if (!supabase) { setState({ kind: 'error', message: 'Dashboard data is unavailable until Supabase is configured.' }); return }
    setState({ kind: 'loading' })
    try { setState({ kind: 'ready', data: await fetchDashboardData(supabase) }) }
    catch { setState({ kind: 'error', message: 'We could not load your dashboard. Please try again.' }) }
  }, [])
  useEffect(() => { void load() }, [load])
  return <DashboardView name={profile?.full_name?.split(' ')[0] ?? 'Student'} state={state} onRetry={load} />
}

export function DashboardView({ name, state, onRetry }: { name: string; state: DashboardState; onRetry?: () => void }) {
  if (state.kind === 'loading') return <DashboardLoading />
  if (state.kind === 'error') return <DashboardError message={state.message} onRetry={onRetry} />
  const { subjects, exams, attempts } = state.data
  const progress = getProgressSummary(attempts)
  return <section className="space-y-7">
    <header className="overflow-hidden rounded-3xl bg-gradient-to-br from-blue-700 via-blue-700 to-indigo-700 p-6 text-white shadow-lg sm:p-10"><p className="text-sm font-semibold text-blue-100">Class 12 learning hub</p><h1 className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">Hello, {name}.</h1><p className="mt-3 max-w-2xl text-blue-100">Keep your preparation steady—review a chapter, choose a practice exam, and track every completed attempt.</p></header>
    <section aria-labelledby="progress-title"><div className="mb-3 flex items-baseline justify-between"><h2 id="progress-title" className="text-xl font-bold">Your progress</h2><span className="text-sm text-slate-500">Based on completed attempts</span></div><div className="grid gap-3 sm:grid-cols-3"><Stat label="Completed exams" value={String(progress.completed)} /><Stat label="Average score" value={progress.averagePercent === null ? '—' : `${Math.round(progress.averagePercent)}%`} /><Stat label="Best score" value={progress.bestPercent === null ? '—' : `${Math.round(progress.bestPercent)}%`} /></div></section>
    <section aria-labelledby="subjects-title"><SectionTitle id="subjects-title" title="Subjects and chapters" description="Start with a chapter and build a focused study plan." />{subjects.length === 0 ? <EmptyState title="No subjects published yet" detail="Your teacher or administrator will add subjects soon." /> : <div className="grid gap-4 md:grid-cols-2">{subjects.map((subject) => <article key={subject.id} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><h3 className="text-lg font-bold">{subject.name}</h3>{subject.chapters.length ? <ul className="mt-3 space-y-2 text-sm text-slate-600">{subject.chapters.map((chapter) => <li key={chapter.id} className="flex gap-2"><span className="font-semibold text-blue-700">{chapter.sort_order}.</span>{chapter.name}</li>)}</ul> : <p className="mt-3 text-sm text-slate-500">Chapters will be available soon.</p>}</article>)}</div>}</section>
    <section aria-labelledby="exams-title"><SectionTitle id="exams-title" title="Published exams" description="Pick an exam when you are ready to practise." />{exams.length === 0 ? <EmptyState title="No published exams yet" detail="Check back soon for practice exams." /> : <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">{exams.map((exam) => <article key={exam.id} className="flex min-h-44 flex-col rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm font-semibold text-blue-700">Practice exam</p><h3 className="mt-1 text-lg font-bold">{exam.title}</h3><p className="mt-2 flex-1 text-sm text-slate-600">{exam.description ?? 'A focused Class 12 practice exam.'}</p><p className="mt-4 text-sm font-medium text-slate-500">{formatDuration(exam.duration_seconds)}</p><span className="mt-3 text-sm font-semibold text-slate-400">Exam launch coming soon</span></article>)}</div>}</section>
    <section aria-labelledby="attempts-title"><SectionTitle id="attempts-title" title="Recent attempts" description="Your latest exam activity." />{attempts.length === 0 ? <EmptyState title="No attempts yet" detail="Your completed and in-progress exams will appear here." /> : <AttemptsTable attempts={attempts} />}</section>
  </section>
}

function SectionTitle({ id, title, description }: { id: string; title: string; description: string }) { return <div className="mb-3"><h2 id={id} className="text-xl font-bold">{title}</h2><p className="mt-1 text-sm text-slate-600">{description}</p></div> }
function Stat({ label, value }: { label: string; value: string }) { return <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p className="text-sm font-medium text-slate-600">{label}</p><p className="mt-2 text-3xl font-bold tracking-tight">{value}</p></article> }
function EmptyState({ title, detail }: { title: string; detail: string }) { return <div className="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-6 text-center"><h3 className="font-bold">{title}</h3><p className="mx-auto mt-1 max-w-md text-sm text-slate-600">{detail}</p></div> }
function DashboardLoading() { return <section aria-label="Loading dashboard" className="space-y-6"><div className="h-56 animate-pulse rounded-3xl bg-slate-200" /><div className="grid gap-4 sm:grid-cols-3">{[1, 2, 3].map((item) => <div key={item} className="h-28 animate-pulse rounded-2xl bg-slate-200" />)}</div><div className="h-52 animate-pulse rounded-2xl bg-slate-200" /></section> }
function DashboardError({ message, onRetry }: { message: string; onRetry?: () => void }) { return <section role="alert" className="rounded-2xl border border-rose-200 bg-rose-50 p-6"><h1 className="text-xl font-bold text-rose-900">Your dashboard could not load</h1><p className="mt-2 text-sm text-rose-800">{message}</p>{onRetry && <button onClick={onRetry} className="mt-4 rounded-xl bg-rose-700 px-4 py-2 text-sm font-semibold text-white hover:bg-rose-800">Try again</button>}</section> }
function AttemptsTable({ attempts }: { attempts: RecentAttempt[] }) { return <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm"><ul className="divide-y divide-slate-100">{attempts.map((attempt) => <li key={attempt.id} className="flex flex-wrap items-center justify-between gap-3 p-4"><div><h3 className="font-semibold">{attempt.exams?.title ?? 'Practice exam'}</h3><p className="mt-1 text-sm text-slate-500">{new Date(attempt.started_at).toLocaleDateString()}</p></div><div className="text-right"><p className="font-bold">{attempt.score !== null && attempt.max_score !== null ? `${attempt.score} / ${attempt.max_score}` : attempt.status === 'in_progress' ? 'In progress' : 'Not scored'}</p><p className="mt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">{attempt.status}</p></div></li>)}</ul></div> }

