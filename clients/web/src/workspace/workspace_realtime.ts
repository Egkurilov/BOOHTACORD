import { loadCurrentSession } from '../identity/current_session'
import type { RealtimeEvent } from '../realtime/realtime_client'
import type { useRealtimeStore } from '../realtime/realtime_store'
import { useNotificationStore } from '../notification/notification_store'
import type { useGuildPresence } from '../identity/guild_presence'
import type { useVoiceConnectionStore } from '../voice/connection_store'
import { useVoiceNavigationStore } from '../voice/navigation_store'
import type { VoiceLeaseRevocationReason } from '../voice/voice_lease_revocation_reason'
import { refreshDirectMessageHint } from './direct_message_realtime'
import { refreshTopologyHint } from './topology_realtime'
import { applyVoiceLeaseRevocation } from './voice_lease_realtime'
import { shouldRefreshTextHistory } from './active_message_resync'
import { usePermissionStore } from '../authorization/permission_store'
import { notifyOwnSessionsChanged } from '../identity/own_sessions/state'

interface Refreshable { error: string | null; refresh(): Promise<void> }
interface TextHistory extends Refreshable { channelId: string | null }
interface DirectHistory {
  directMessageId: string | null
  error: string | null
  refreshNavigation(): Promise<void>
  refreshHistory(): Promise<void>
}
export interface WorkspaceRealtimeStores {
  topology: Refreshable
  messages: TextHistory
  directMessages: DirectHistory
}

async function checked(refresh: () => Promise<void>, getError: () => string | null): Promise<void> {
  await refresh()
  if (getError()) throw new Error(getError()!)
}

export async function refreshProtectedState(stores: WorkspaceRealtimeStores): Promise<void> {
  const { topology, messages, directMessages } = stores
  const textActive = Boolean(messages.channelId && !directMessages.directMessageId)
  const directActive = Boolean(directMessages.directMessageId)
  await Promise.all([
    checked(() => topology.refresh(), () => topology.error),
    (async () => {
      await checked(() => directMessages.refreshNavigation(), () => directMessages.error)
      if (directActive) await checked(() => directMessages.refreshHistory(), () => directMessages.error)
    })(),
    textActive ? checked(() => messages.refresh(), () => messages.error) : Promise.resolve(),
  ])
}

export function createWorkspaceRealtime(stores: WorkspaceRealtimeStores, realtime: ReturnType<typeof useRealtimeStore>, presence: ReturnType<typeof useGuildPresence>, voice: ReturnType<typeof useVoiceConnectionStore>, accountID: string, onSessionExpired: () => void) {
  const voiceNavigation = useVoiceNavigationStore()
  const notifications = useNotificationStore()
  const permissions = usePermissionStore()
  let active = false
  let lifecycle = 0
  function onEvent(event: RealtimeEvent): void | Promise<void> {
    if (!active) return
    const eventLifecycle = lifecycle
    if (presence.acceptRealtimeEvent(event)) return
    if (event.kind === 'session.state_changed') { notifyOwnSessionsChanged(); return }
    if (event.kind === 'connection.resync_required') return refreshProtectedState(stores)
    if (event.kind === 'direct_message.message_created' || event.kind === 'direct_message.message_updated' || event.kind === 'direct_message.message_deleted') {
      const previousUnread = notifications.capture(event)
      return refreshDirectMessageHint(stores.directMessages, event.payload.direct_message_id as string).then(() => {
        if (active && lifecycle === eventLifecycle) return notifications.deliver(event, previousUnread)
      })
    }
    if (event.kind === 'channel.updated') return refreshTopologyHint(stores.topology)
    if (event.kind === 'role.permissions.updated' || event.kind === 'auth.permissions.invalidated') return permissions.refresh()
    if (event.kind === 'voice.lease_revoked') return applyVoiceLeaseRevocation(voice, voiceNavigation, event.payload.lease_id as string, event.payload.reason as VoiceLeaseRevocationReason)
    if (event.kind === 'message.created' || event.kind === 'message.updated' || event.kind === 'message.deleted') {
      const previousUnread = notifications.capture(event)
      const visible = shouldRefreshTextHistory(event, stores.messages.channelId, Boolean(stores.directMessages.directMessageId))
      return Promise.all([
        checked(() => stores.topology.refresh(), () => stores.topology.error),
        visible ? checked(() => stores.messages.refresh(), () => stores.messages.error) : Promise.resolve(),
      ]).then(() => {
        if (active && lifecycle === eventLifecycle) return notifications.deliver(event, previousUnread)
      })
    }
    return refreshProtectedState(stores)
  }

  return {
    start(): void {
      active = true
      lifecycle += 1
      notifications.start(accountID)
      realtime.connect(onEvent, undefined, undefined, {
        onRecovery: () => Promise.all([refreshProtectedState(stores), permissions.refresh()]).then(() => undefined),
        checkSession: async () => (await loadCurrentSession())?.accountId === accountID,
        onSessionExpired,
      })
    },
    stop(): void { active = false; lifecycle += 1; realtime.disconnect(); notifications.stop() },
  }
}
