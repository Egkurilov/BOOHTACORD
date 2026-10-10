import type { ChannelTopology, TopologyChannel } from '../channel/topology_client'

export interface WorkspaceLocationHistory {
  readonly state: unknown
  pushState(data: unknown, title?: string, url?: string | URL | null): void
  replaceState(data: unknown, title?: string, url?: string | URL | null): void
}

const workspaceChannelPrefix = '#workspace/channel/'

export function isWorkspaceChannelLocationHash(hash: string): boolean {
  return hash === '#workspace/channel' || hash.startsWith(workspaceChannelPrefix)
}

export function parseWorkspaceChannelLocation(hash: string): string | null {
  if (!hash.startsWith(workspaceChannelPrefix)) return null
  const encodedChannelId = hash.slice(workspaceChannelPrefix.length)
  if (!encodedChannelId || encodedChannelId.includes('/')) return null
  try {
    const channelId = decodeURIComponent(encodedChannelId)
    return channelId.trim() ? channelId : null
  } catch {
    return null
  }
}

/** Resolve URL input only against the channels returned for the current account. */
export function findAccessibleWorkspaceChannel(
  topology: ChannelTopology | null,
  channelId: string,
): TopologyChannel | null {
  if (!topology || !channelId) return null
  return topology.categories.flatMap(({ channels }) => channels).find(({ id }) => id === channelId) ?? null
}

export function restoreWorkspaceChannelFromLocation(
  hash: string,
  topology: ChannelTopology | null,
  history: WorkspaceLocationHistory,
  currentUrl: string,
  selectChannel: (channel: TopologyChannel) => void,
): 'ignored' | 'waiting' | 'selected' | 'invalid' {
  if (!isWorkspaceChannelLocationHash(hash)) return 'ignored'
  if (!topology) return 'waiting'
  const channelId = parseWorkspaceChannelLocation(hash)
  const channel = channelId ? findAccessibleWorkspaceChannel(topology, channelId) : null
  if (!channel) {
    clearWorkspaceChannelLocation(history, currentUrl)
    return 'invalid'
  }
  selectChannel(channel)
  return 'selected'
}

export function setWorkspaceChannelLocation(
  history: WorkspaceLocationHistory,
  currentUrl: string,
  channelId: string,
  replace = false,
): void {
  if (!channelId.trim()) return
  const url = new URL(currentUrl)
  const nextHash = `${workspaceChannelPrefix}${encodeURIComponent(channelId)}`
  if (url.hash === nextHash) return
  url.hash = nextHash.slice(1)
  if (replace) history.replaceState(history.state, '', url)
  else history.pushState(history.state, '', url)
}

export function clearWorkspaceChannelLocation(
  history: WorkspaceLocationHistory,
  currentUrl: string,
): boolean {
  const url = new URL(currentUrl)
  if (!isWorkspaceChannelLocationHash(url.hash)) return false
  url.hash = ''
  history.replaceState(history.state, '', url)
  return true
}
