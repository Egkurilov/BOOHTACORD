const pastels = [
  { backgroundColor: '#f6d8dc', color: '#5b2834' },
  { backgroundColor: '#e8dcfa', color: '#473369' },
  { backgroundColor: '#d8ecfa', color: '#254b65' },
  { backgroundColor: '#d7f0e8', color: '#245446' },
  { backgroundColor: '#f8e6c4', color: '#624715' },
  { backgroundColor: '#f4dfd2', color: '#674030' },
  { backgroundColor: '#ddedf0', color: '#31565f' },
  { backgroundColor: '#e9e5fa', color: '#48466b' },
] as const

export function avatarFallbackStyle(authorId: string): { backgroundColor: string; color: string } {
  let hash = 2166136261
  for (let index = 0; index < authorId.length; index += 1) {
    hash = Math.imul(hash ^ authorId.charCodeAt(index), 16777619) >>> 0
  }
  return pastels[hash % pastels.length]
}
