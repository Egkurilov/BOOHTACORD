export function miniPlayerVisible(pinned: boolean, voiceVisible: boolean, selectedId: string | null, activeVoiceChannelId: string | null): boolean {
  return pinned && !voiceVisible && Boolean(selectedId && activeVoiceChannelId)
}

export function screenViewerMounted(pinned: boolean, voiceVisible: boolean, selectedId: string | null, activeVoiceChannelId: string | null): boolean {
  return voiceVisible || miniPlayerVisible(pinned, voiceVisible, selectedId, activeVoiceChannelId)
}
