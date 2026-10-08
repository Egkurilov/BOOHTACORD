let currentRetry: (() => void) | null = null
let currentOwner = 0

export function registerVoiceRosterRetry(retry: () => void): () => void {
  const owner = ++currentOwner
  currentRetry = retry
  return () => {
    if (currentOwner !== owner) return
    currentRetry = null
    currentOwner++
  }
}

export function retryVoiceRoster(): boolean {
  if (currentRetry === null) return false
  currentRetry()
  return true
}
