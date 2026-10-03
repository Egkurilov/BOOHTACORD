const palette = [
  { backgroundColor: '#17464a', color: '#f4f5fa' },
  { backgroundColor: '#553521', color: '#f4f5fa' },
  { backgroundColor: '#393059', color: '#f4f5fa' },
  { backgroundColor: '#423657', color: '#f4f5fa' },
  { backgroundColor: '#556176', color: '#f4f5fa' },
] as const

export function avatarFallbackStyle(authorId: string): { backgroundColor: string; color: string } {
  let hash = 2166136261
  for (let index = 0; index < authorId.length; index += 1) {
    hash = Math.imul(hash ^ authorId.charCodeAt(index), 16777619) >>> 0
  }
  return palette[hash % palette.length]
}
