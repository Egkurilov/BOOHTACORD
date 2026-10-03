export const permissionKeys = [
  'channel.text.create', 'channel.text.delete', 'channel.voice.create',
  'channel.voice.delete', 'category.create', 'category.delete',
] as const

export type PermissionKey = typeof permissionKeys[number]
export type PermissionValues = Record<PermissionKey, boolean>

export const memberPermissionDefaults = (): PermissionValues => ({
  'channel.text.create': true, 'channel.text.delete': false,
  'channel.voice.create': true, 'channel.voice.delete': false,
  'category.create': true, 'category.delete': false,
})

export function parsePermissionValues(value: unknown): PermissionValues {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('Сервер вернул некорректные разрешения.')
  const source = value as Record<string, unknown>
  if (Object.keys(source).length !== permissionKeys.length || permissionKeys.some((key) => typeof source[key] !== 'boolean')) throw new Error('Сервер вернул некорректные разрешения.')
  return Object.fromEntries(permissionKeys.map((key) => [key, source[key]])) as PermissionValues
}
