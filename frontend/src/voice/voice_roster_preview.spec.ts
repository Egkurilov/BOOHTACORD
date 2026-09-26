import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import ChannelNavigation from '../channel/ChannelNavigation.vue'
import VoicePrejoin from './VoicePrejoin.vue'

const roster = { channelId: 'voice-1', participants: [{ accountId: 'user-1', displayName: 'Мика', screenSharing: true }] }

describe('prejoin voice roster', () => {
  it('shows current speakers and stream state in navigation without joining', async () => {
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      activeVoiceChannelId: undefined, selectedChannelId: 'voice-1', voicePresence: null, voiceRosters: [roster],
      topology: { revision: 1, categories: [{ id: 'cat-1', name: 'Игры', position: 0, channels: [
        { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 0, admissionClosed: false },
      ] }] },
    }))
    expect(html).toContain('Мика')
    expect(html).toContain('Сейчас в канале: 1')
    expect(html).toContain('Показывает экран')
    expect(html).not.toContain('· вы')
  })

  it('shows connected members before Join and distinguishes unavailable roster', async () => {
    const base = { channelId: 'voice-1', voiceError: null, voiceState: 'IDLE', voiceTransferRequired: false }
    const html = await renderToString(createSSRApp(VoicePrejoin, { ...base, roster }))
    expect(html).toContain('Мика')
    expect(html).toContain('Сейчас в канале')
    expect(html).toContain('Идёт трансляция')
    const unavailable = await renderToString(createSSRApp(VoicePrejoin, { ...base, roster: null, rosterError: '503' }))
    expect(unavailable).toContain('Не удалось обновить состав')
    expect(unavailable).not.toContain('Никого нет')
  })
})
