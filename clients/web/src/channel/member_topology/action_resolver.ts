import type { PermissionValues } from '../../authorization/permission_keys'
import type { ChannelKind } from '../topology_client'

export function categoryActions(permissions: PermissionValues, empty: boolean) {
  return { createText: permissions['channel.text.create'], createVoice: permissions['channel.voice.create'], delete: empty && permissions['category.delete'] }
}
export function channelActions(permissions: PermissionValues, kind: ChannelKind) {
  return { delete: permissions[kind === 'TEXT' ? 'channel.text.delete' : 'channel.voice.delete'] }
}
