import '@testing-library/jest-dom/vitest'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { DashboardView } from './DashboardPage'

describe('DashboardView', () => {
  it('shows useful empty states without inventing data', () => {
    render(<DashboardView name="Aarav" state={{ kind: 'ready', data: { subjects: [], exams: [], attempts: [] } }} />)
    expect(screen.getByRole('heading', { name: 'Hello, Aarav.' })).toBeInTheDocument()
    expect(screen.getByText('No subjects published yet')).toBeInTheDocument()
    expect(screen.getByText('No published exams yet')).toBeInTheDocument()
    expect(screen.getByText('No attempts yet')).toBeInTheDocument()
  })
  it('shows a retry option for a loading failure', () => {
    render(<DashboardView name="Aarav" state={{ kind: 'error', message: 'Could not connect.' }} onRetry={() => undefined} />)
    expect(screen.getByRole('alert')).toHaveTextContent('Could not connect.')
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument()
  })
})

