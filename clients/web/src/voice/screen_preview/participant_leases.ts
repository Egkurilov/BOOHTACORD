let leasesByParticipant = new Map<string, string>()

export function replaceScreenPreviewParticipantLeases(entries: Iterable<readonly [string, string]>): void {
  leasesByParticipant = new Map(entries)
}

export function screenPreviewLeaseForParticipant(participantId: string): string | undefined {
  return leasesByParticipant.get(participantId)
}
