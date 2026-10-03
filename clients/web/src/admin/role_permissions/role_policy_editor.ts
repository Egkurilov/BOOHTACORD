import { permissionKeys, type PermissionKey, type PermissionValues } from '../../authorization/permission_keys'

const deleteKeys: PermissionKey[] = ['channel.text.delete', 'channel.voice.delete', 'category.delete']
export function copyPermissions(values: PermissionValues): PermissionValues { return { ...values } }
export function changed(baseline: PermissionValues, draft: PermissionValues): boolean { return permissionKeys.some((key) => baseline[key] !== draft[key]) }
export function newlyGrantedDeletes(baseline: PermissionValues, draft: PermissionValues): PermissionKey[] { return deleteKeys.filter((key) => !baseline[key] && draft[key]) }
