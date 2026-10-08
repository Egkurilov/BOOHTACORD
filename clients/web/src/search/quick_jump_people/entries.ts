import type { QuickJumpPerson } from '../quick_jump'
import type { DirectMessageCandidate } from '../../direct_message/direct_message_candidate_client'

interface Dialog { id: string; otherParticipantId: string; otherParticipantDisplayName: string }
export function quickJumpPeople(dialogs: readonly Dialog[], candidates: readonly DirectMessageCandidate[]): QuickJumpPerson[] {
  const byParticipant = new Map(candidates.map(person => [person.id, person.displayName]))
  const existing = new Set(dialogs.map(dialog => dialog.otherParticipantId))
  return [
    ...dialogs.map(dialog => ({ id: dialog.id, kind: 'DIRECT_MESSAGE' as const,
      displayName: byParticipant.get(dialog.otherParticipantId) ?? dialog.otherParticipantDisplayName })),
    ...candidates.filter(person => !existing.has(person.id)).map(person => ({ ...person, kind: 'MEMBER' as const })),
  ]
}
