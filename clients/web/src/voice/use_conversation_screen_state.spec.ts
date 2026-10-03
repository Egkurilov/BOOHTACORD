import { effectScope, nextTick, reactive } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { useConversationScreenState } from './use_conversation_screen_state'
import type { ScreenViewerCard } from './screen_viewer_controller'

function localScreen(id = 'local:account:screen'): ScreenViewerCard {
  return { hasAudio: false, id, isLocal: true, participantId: 'account', participantName: 'Ваш экран' }
}

function voiceChannel() {
  return { id: 'voice', kind: 'VOICE' as const, name: 'Общий', position: 0, admissionClosed: false }
}

describe('conversation local screen preview', () => {
  it('opens the local screen when it becomes available and nothing else is selected', async () => {
    const props = reactive({
      visible: true,
      channel: voiceChannel(),
      activeVoiceChannel: null,
      directMessage: null,
      selectedScreenStreamId: null,
      screenViewerCards: [] as ReturnType<typeof localScreen>[],
      screenViewerEnded: false,
    })
    const scope = effectScope()
    let state!: ReturnType<typeof useConversationScreenState>
    scope.run(() => { state = useConversationScreenState(props) })
    const selectStream = vi.fn()
    state.screenViewerRef.value = { selectStream } as never

    props.screenViewerCards.push(localScreen())
    await nextTick()
    await nextTick()

    expect(selectStream).toHaveBeenCalledWith('local:account:screen')
    scope.stop()
  })

  it('does not reopen a local preview after the user closes it', async () => {
    const props = reactive({
      visible: true,
      channel: voiceChannel(),
      activeVoiceChannel: null,
      directMessage: null,
      selectedScreenStreamId: 'local:account:screen' as string | null,
      screenViewerCards: [localScreen()],
      screenViewerEnded: false,
    })
    const scope = effectScope()
    let state!: ReturnType<typeof useConversationScreenState>
    scope.run(() => { state = useConversationScreenState(props) })
    const selectStream = vi.fn()
    state.screenViewerRef.value = { selectStream } as never

    state.dismissLocalPreview()
    props.selectedScreenStreamId = null
    await nextTick()
    await nextTick()

    expect(selectStream).not.toHaveBeenCalled()
    scope.stop()
  })

  it('does not replace a remote selection or an ended remote stream with the local preview', async () => {
    const props = reactive({
      visible: true,
      channel: voiceChannel(),
      activeVoiceChannel: null,
      directMessage: null,
      selectedScreenStreamId: 'remote:screen' as string | null,
      screenViewerCards: [localScreen()],
      screenViewerEnded: false,
    })
    const scope = effectScope()
    let state!: ReturnType<typeof useConversationScreenState>
    scope.run(() => { state = useConversationScreenState(props) })
    const selectStream = vi.fn()
    state.screenViewerRef.value = { selectStream } as never

    props.selectedScreenStreamId = null
    props.screenViewerEnded = true
    await nextTick()
    await nextTick()

    expect(selectStream).not.toHaveBeenCalled()
    scope.stop()
  })
})
