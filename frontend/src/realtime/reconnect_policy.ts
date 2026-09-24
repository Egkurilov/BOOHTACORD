export function reconnectDelay(attempt: number, random: () => number = Math.random): number {
  const base = Math.min(15_000, 500 * 2 ** Math.min(Math.max(0, attempt), 5))
  const jitter = 0.8 + Math.min(1, Math.max(0, random())) * 0.4
  return Math.min(15_000, Math.round(base * jitter))
}
