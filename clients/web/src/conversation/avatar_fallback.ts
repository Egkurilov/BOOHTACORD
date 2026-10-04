const palette = [
  { backgroundColor: '#17464a', color: '#a5f2f0' },
  { backgroundColor: '#553521', color: '#ffd5a8' },
  { backgroundColor: '#393059', color: '#e3dcff' },
  { backgroundColor: '#423657', color: '#e9cbff' },
  { backgroundColor: '#556176', color: '#f4f5fa' },
] as const

export function avatarFallbackStyle(authorId: string): { backgroundColor: string; color: string } {
  let hash = 2166136261
  for (let index = 0; index < authorId.length; index += 1) {
    hash = Math.imul(hash ^ authorId.charCodeAt(index), 16777619) >>> 0
  }
  return palette[hash % palette.length]
}
