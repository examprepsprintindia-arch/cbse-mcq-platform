import { describe, expect, it } from 'vitest'
import { formatDuration, getProgressSummary, type RecentAttempt } from './dashboardData'

const attempts: RecentAttempt[] = [
  { id: '1', status: 'submitted', score: 8, max_score: 10, started_at: '2026-01-01T00:00:00Z', submitted_at: '2026-01-01T00:10:00Z', exams: { title: 'Physics' } },
  { id: '2', status: 'submitted', score: 6, max_score: 10, started_at: '2026-01-02T00:00:00Z', submitted_at: '2026-01-02T00:10:00Z', exams: { title: 'Chemistry' } },
  { id: '3', status: 'in_progress', score: null, max_score: null, started_at: '2026-01-03T00:00:00Z', submitted_at: null, exams: { title: 'Maths' } },
]

describe('dashboard summary', () => {
  it('uses only scored student attempts for progress', () => expect(getProgressSummary(attempts)).toEqual({ completed: 2, averagePercent: 70, bestPercent: 80 }))
  it('returns empty summary values when no attempt is scored', () => expect(getProgressSummary([attempts[2]])).toEqual({ completed: 0, averagePercent: null, bestPercent: null }))
  it('formats exam duration for students', () => expect(formatDuration(900)).toBe('15 min'))
})

