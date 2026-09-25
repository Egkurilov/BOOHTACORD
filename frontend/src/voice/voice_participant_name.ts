interface VerifiedMemberNames { verifiedDisplayName(id: string): string | null }

export function voiceParticipantName(directory: VerifiedMemberNames, accountId: string | null | undefined, liveKitName: string | undefined): string | undefined {
  const tokenName = liveKitName?.trim() || undefined
  return accountId ? directory.verifiedDisplayName(accountId) ?? tokenName : tokenName
}
