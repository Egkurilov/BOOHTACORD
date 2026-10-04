const palette = [
  { background: 'blue', foreground: '#A5F2F0' },
  { background: 'green', foreground: '#FFD5A8' },
  { background: 'violet', foreground: '#E3DCFF' },
  { background: 'orange', foreground: '#E9CBFF' },
  { background: 'gray', foreground: '#F4F5FA' },
] as const

function avatarTone(identity: string): typeof palette[number] {
  let hash = 2166136261
  for (const character of identity) hash = Math.imul(hash ^ character.charCodeAt(0), 16777619)
  return palette[(hash >>> 0) % palette.length]
}

export function avatarBackground(identity: string): string { return `var(--gc-avatar-${avatarTone(identity).background})` }
export function avatarForeground(identity: string): string { return avatarTone(identity).foreground }
