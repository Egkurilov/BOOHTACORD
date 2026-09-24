import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { avatarBackground } from './avatar_color'

function source(path: string): string {
  return readFileSync(new URL(path, import.meta.url), 'utf8')
}

describe('GuildChat reference fidelity', () => {
  it('uses the reference desktop columns and compact drawer instead of a squeezed roster column', () => {
    const shell = source('./shell.css') + source('./responsive_shell.css')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide)')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-medium) minmax(0, 1fr) var(--gc-layout-aside-medium)')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-small) minmax(0, 1fr)')
    expect(shell).toContain('.members.is-open')
    expect(shell).toContain('.sidebar.is-open')
    expect(shell).not.toContain('208px')
  })

  it('gives voice rooms the full content width and keeps their participant panel on demand', () => {
    const shell = source('./responsive_shell.css')
    const app = source('../workspace/WorkspaceApp.vue')
    const actions = source('../workspace/WorkspaceHeaderActions.vue')
    expect(app).toContain("'voice-room-active': !selectedDirectMessage && activePanel === 'none' && selectedChannel?.kind === 'VOICE'")
    expect(app).toContain("selectedChannel?.kind !== 'VOICE' || membersOpen")
    expect(shell).toContain('.gc-shell.voice-room-active')
    expect(shell).toContain('.gc-shell.voice-members-open .drawer-scrim')
    expect(actions).toContain('aria-label="Открыть участников"')
  })

  it('keeps a visible mobile dock and accessible controls for opening both drawers', () => {
    const shell = source('./responsive_shell.css')
    const actions = source('../workspace/WorkspaceHeaderActions.vue')
    const app = source('../workspace/WorkspaceApp.vue')
    expect(shell).toContain('.mobile-voice-dock')
    expect(actions).toContain('aria-label="Открыть навигацию"')
    expect(actions).toContain('aria-label="Открыть участников"')
    expect(app).toContain('drawer-scrim')
    expect(app).toContain('toggleMembers')
  })

  it('shows truthful guild presence groups and only confirmed voice-room participants', () => {
    const panel = source('../workspace/WorkspaceMembersPanel.vue')
    expect(panel).toContain('loadMembers')
    expect(panel).toContain('groupMembersByPresence')
    expect(panel).toContain('presenceResolver')
    expect(source('../workspace/WorkspaceApp.vue')).toContain('guildPresence.resolve')
    expect(panel).toContain("selectedVoiceChannel && !voiceRoomVisible")
    expect(panel).toContain('Голосовой канал ·')
    expect(panel).toContain('voiceStateLabel')
    expect(panel).toContain('Подключитесь к каналу, чтобы увидеть его участников.')
    expect(panel).toContain('В сети')
    expect(panel).toContain('Не в сети')
    expect(panel).toContain('Статус неизвестен')
    expect(panel).not.toContain('Away')
  })

  it('keeps C-29 participant cards readable and status-visible', () => {
    const cards = source('../voice/VoiceParticipantVolumes.vue')
    const voice = source('./voice.css')
    expect(cards).toContain('participant-grid')
    expect(cards).toContain('voice-participant-self')
    expect(cards).toContain('<VoiceParticipantStatus')
    expect(voice).toContain('min-height: 144px')
    expect(voice).toContain('minmax(160px, 1fr)')
    expect(voice).toContain('overflow: auto')
  })

  it('assigns decorative avatar colors deterministically without encoding presence', () => {
    expect(avatarBackground('member-42')).toBe(avatarBackground('member-42'))
    expect(avatarBackground('member-42')).toMatch(/^var\(--gc-avatar-(blue|green|violet|orange|gray)\)$/)
  })
})
