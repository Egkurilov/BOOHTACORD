import type { ChannelTopology, TopologyCategory, TopologyChannel } from '../topology_client'

export function confirmedTargetIsCurrent(
  topology: ChannelTopology,
  target: TopologyCategory | TopologyChannel,
  confirmedRevision: number,
): boolean {
  if (topology.revision !== confirmedRevision) return false

  if ('channels' in target) {
    const category = topology.categories.find(({ id }) => id === target.id)
    return category?.name === target.name && category.channels.length === 0
  }

  const channel = topology.categories.flatMap(({ channels }) => channels).find(({ id }) => id === target.id)
  return channel?.kind === target.kind && channel.name === target.name
}
