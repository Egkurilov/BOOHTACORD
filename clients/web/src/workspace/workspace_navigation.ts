import { computed, ref, type Ref } from 'vue'

import type { TopologyChannel } from '../channel/topology_client'
import { useDirectMessageCandidateStore } from '../direct_message/direct_message_candidate_store'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import { useTopologyStore } from '../channel/topology_store'
import { useMemberHeaderExpanded } from './member_header_expanded'
import { useWorkspaceDrawers } from './useWorkspaceDrawers'

type Panel = 'none' | 'admin' | 'audio' | 'profile' | 'search'

export function useWorkspaceNavigation(role: 'MEMBER' | 'ADMINISTRATOR', selectedChannel: Readonly<Ref<TopologyChannel | null>>, topologyStore: ReturnType<typeof useTopologyStore>, selectWorkspaceChannel: (channel: TopologyChannel) => void, selectWorkspaceDirectMessage: (id: string) => void) {
  const directMessageStore = useDirectMessageStore()
  const directMessageCandidateStore = useDirectMessageCandidateStore()
  const sidebarSection = ref<'channels' | 'messages'>('channels')
  const activePanel = ref<Panel>('none')
  const { navOpen, membersOpen, modalDrawer, closeDrawers, toggleNavigation, toggleMembers } = useWorkspaceDrawers(activePanel)
  const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)
  const voiceStageWide = computed(() => selectedChannel.value?.kind === 'VOICE' && !selectedDirectMessage.value && activePanel.value === 'none')
  const memberHeaderExpandedState = useMemberHeaderExpanded(voiceStageWide, membersOpen, closeDrawers)
  function selectChannel(channel: TopologyChannel): void { closeDrawers(); activePanel.value = 'none'; sidebarSection.value = 'channels'; directMessageStore.close(); selectWorkspaceChannel(channel) }
  function returnToVoice(channelId: string): void { const channel = topologyStore.topology?.categories.flatMap(({ channels }) => channels).find(({ id, kind }) => id === channelId && kind === 'VOICE'); if (channel) selectChannel(channel) }
  function selectDirectMessage(id: string): void { closeDrawers(); activePanel.value = 'none'; sidebarSection.value = 'messages'; selectWorkspaceDirectMessage(id); void directMessageStore.open(id) }
  async function selectOpenedDirectMessage(id: string): Promise<void> { await directMessageStore.refreshNavigation(); selectDirectMessage(id) }
  async function openDirectMessageFromMember(userID: string): Promise<void> {
    activePanel.value = 'none'; sidebarSection.value = 'messages'; directMessageStore.close()
    const directMessageID = await directMessageCandidateStore.open(userID)
    if (directMessageID) await selectOpenedDirectMessage(directMessageID)
    else directMessageStore.error = directMessageCandidateStore.error ?? 'Не удалось открыть личное сообщение.'
  }
  function togglePanel(panel: Exclude<Panel, 'none'>): void { closeDrawers(); activePanel.value = activePanel.value === panel ? 'none' : panel }
  function openGuildPanel(): void { if (role === 'ADMINISTRATOR') togglePanel('admin') }
  return { activePanel, closeDrawers, directMessageStore, memberHeaderExpandedState, membersOpen, modalDrawer, navOpen, openDirectMessageFromMember, openGuildPanel, returnToVoice, selectedDirectMessage, selectChannel, selectDirectMessage, selectOpenedDirectMessage, sidebarSection, toggleMembers, toggleNavigation, togglePanel, voiceStageWide }
}
