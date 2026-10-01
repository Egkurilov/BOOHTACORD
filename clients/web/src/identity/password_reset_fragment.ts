interface ResetLocation { pathname: string; search: string; hash: string }
interface ResetHistory { state: unknown; replaceState(state: unknown, unused: string, url: string): void }

export interface ResetFragment { resetRoute: boolean; token: string | null }

/** Called synchronously during App setup, before session or maintenance requests. */
export function consumePasswordResetFragment(location: ResetLocation, history: ResetHistory): ResetFragment {
  if (location.pathname !== '/reset-password') return { resetRoute: false, token: null }
  const token = location.hash.startsWith('#') ? new URLSearchParams(location.hash.slice(1)).get('token') : null
  if (location.hash || location.search) history.replaceState(history.state, '', '/reset-password')
  return { resetRoute: true, token: token || null }
}
