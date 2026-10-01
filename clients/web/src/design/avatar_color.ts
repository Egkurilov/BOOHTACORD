const palette = ['blue', 'green', 'violet', 'orange', 'gray'] as const

export function avatarBackground(identity: string): string {
  let hash = 2166136261
  for (const character of identity) hash = Math.imul(hash ^ character.charCodeAt(0), 16777619)
  return `var(--gc-avatar-${palette[(hash >>> 0) % palette.length]})`
}
