export function avatarInitials(name: string | null | undefined, fallback = 'У'): string {
  return name?.match(/\p{L}/gu)?.slice(0, 2).join('').toLocaleUpperCase('ru-RU') || fallback
}
