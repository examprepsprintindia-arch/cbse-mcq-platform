import { useAuth } from '../auth/AuthProvider'

export function DashboardPage() {
  const { profile } = useAuth()
  const name = profile?.full_name?.split(' ')[0] ?? 'Student'
  return <section className="space-y-7"><div className="rounded-3xl bg-gradient-to-br from-blue-700 to-indigo-700 p-6 text-white shadow-lg sm:p-10"><p className="text-sm font-semibold text-blue-100">Class 12 learning hub</p><h1 className="mt-2 text-3xl font-bold sm:text-4xl">Hello, {name}.</h1><p className="mt-3 max-w-xl text-blue-100">Your exam dashboard is ready. Subjects, practice exams, and progress insights will arrive in the next phase.</p></div><div className="grid gap-4 sm:grid-cols-3"><Card title="Subjects" text="Browse your Class 12 syllabus." /><Card title="Practice" text="Take a timed exam when ready." /><Card title="Progress" text="See your learning streak grow." /></div></section>
}
function Card({ title, text }: { title: string; text: string }) { return <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><h2 className="font-bold">{title}</h2><p className="mt-2 text-sm text-slate-600">{text}</p><span className="mt-4 inline-block text-sm font-semibold text-blue-700">Coming soon</span></article> }

