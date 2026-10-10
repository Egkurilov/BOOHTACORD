import { createApp, computed, h } from 'vue'
import { createPinia, setActivePinia } from 'pinia'
import type { TopologyChannel } from '../../src/channel/topology_client'
import { useTopologyStore } from '../../src/channel/topology_store'
import { useVoiceNavigationStore } from '../../src/voice/navigation_store'
import { useWorkspaceNavigation } from '../../src/workspace/workspace_navigation'

const root = document.querySelector<HTMLDivElement>('#app')
if (!root) throw new Error('Missing app root')

const pinia = createPinia()
setActivePinia(pinia)
const topology = useTopologyStore(pinia)
const voiceNavigation = useVoiceNavigationStore(pinia)
const channels: TopologyChannel[] = [
  { id: 'channel-1', name: 'общее', kind: 'TEXT', position: 0, admissionClosed: false },
  { id: 'channel-2', name: 'объявления', kind: 'TEXT', position: 1, admissionClosed: false },
]
topology.topology = {
  revision: 1,
  categories: [{ id: 'category-1', name: 'Каналы', position: 0, channels }],
}
voiceNavigation.selectText(channels[0].id)
const selectedChannel = computed(() => {
  const selected = voiceNavigation.selectedSurface
  return selected.kind === 'TEXT' || selected.kind === 'VOICE'
    ? channels.find(({ id }) => id === selected.channelId) ?? null
    : null
})

const app = createApp({
  setup() {
    const navigation = useWorkspaceNavigation(
      'MEMBER',
      selectedChannel,
      topology,
      (channel) => voiceNavigation.selectText(channel.id),
      (id) => voiceNavigation.selectDirectMessage(id),
    )
    return () => h('main', [
      h('button', { id: 'open-nav', onClick: navigation.toggleNavigation }, 'Навигация'),
      ...channels.map((channel) => h('button', {
        id: `select-${channel.id}`,
        onClick: () => navigation.selectChannel(channel),
      }, channel.name)),
      h('output', { id: 'selected-channel' }, selectedChannel.value?.id ?? 'none'),
      h('output', { id: 'nav-state' }, navigation.navOpen.value ? 'open' : 'closed'),
    ])
  },
})
app.use(pinia).mount(root)
