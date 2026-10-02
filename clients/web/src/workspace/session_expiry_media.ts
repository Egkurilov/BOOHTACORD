interface VoiceSessionTeardown { disconnectLocal(reason: 'SESSION_REVOKED'): Promise<unknown> }

/** Revoke local media immediately; never hold the guest transition on transport teardown. */
export function expireWorkspaceSession(voice: VoiceSessionTeardown, showGuest: () => void): void {
  try {
    void voice.disconnectLocal('SESSION_REVOKED').catch(() => undefined)
  } finally {
    showGuest()
  }
}
