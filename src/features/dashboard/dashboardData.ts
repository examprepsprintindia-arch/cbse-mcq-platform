import type { SupabaseClient } from '@supabase/supabase-js'

export interface SubjectOverview { id: string; name: string; slug: string; chapters: Array<{ id: string; name: string; slug: string; sort_order: number }> }
export interface PublishedExam { id: string; title: string; description: string | null; duration_seconds: number }
export interface RecentAttempt { id: string; status: 'in_progress' | 'submitted' | 'expired'; score: number | null; max_score: number | null; started_at: string; submitted_at: string | null; exams: { title: string } | null }
export interface DashboardData { subjects: SubjectOverview[]; exams: PublishedExam[]; attempts: RecentAttempt[] }

export async function fetchDashboardData(client: SupabaseClient): Promise<DashboardData> {
  // These reads use only the tables/columns already allowed to students by RLS.
  const [subjects, exams, attempts] = await Promise.all([
    client.from('subjects').select('id, name, slug, chapters(id, name, slug, sort_order)').eq('is_published', true).order('sort_order'),
    client.from('exams').select('id, title, description, duration_seconds').eq('is_published', true).order('created_at', { ascending: false }),
    client.from('attempts').select('id, status, score, max_score, started_at, submitted_at, exams(title)').order('started_at', { ascending: false }).limit(5),
  ])
  const error = subjects.error ?? exams.error ?? attempts.error
  if (error) throw error
  return {
    subjects: (subjects.data ?? []).map((subject) => ({ ...subject, chapters: [...(subject.chapters ?? [])].sort((a, b) => a.sort_order - b.sort_order) })) as SubjectOverview[],
    exams: (exams.data ?? []) as PublishedExam[],
    attempts: (attempts.data ?? []).map((attempt) => ({
      ...attempt,
      // Supabase's inferred relation shape can be an array even for this
      // many-to-one relation; the dashboard always renders one exam title.
      exams: Array.isArray(attempt.exams) ? attempt.exams[0] ?? null : attempt.exams,
    })) as RecentAttempt[],
  }
}

export interface ProgressSummary { completed: number; averagePercent: number | null; bestPercent: number | null }
export function getProgressSummary(attempts: RecentAttempt[]): ProgressSummary {
  const percentages = attempts.filter((a) => a.score !== null && a.max_score !== null && a.max_score > 0).map((a) => (a.score! / a.max_score!) * 100)
  return { completed: percentages.length, averagePercent: percentages.length ? percentages.reduce((sum, value) => sum + value, 0) / percentages.length : null, bestPercent: percentages.length ? Math.max(...percentages) : null }
}
export function formatDuration(seconds: number) { return `${Math.round(seconds / 60)} min` }

