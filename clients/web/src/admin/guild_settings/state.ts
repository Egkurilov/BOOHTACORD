import { ref } from 'vue'
import { validGuildName } from '../../guild/profile/client'
import { guildProfile } from '../../guild/profile/state'
import { GuildSettingsError, readGuildSettings, writeGuildSettings } from './client'
export function createGuildSettingsState(read = readGuildSettings, write = writeGuildSettings) {
  const name = ref(''), welcome = ref<string | null>(null), revision = ref(0), busy = ref(false), error = ref<string | null>(null), saved = ref(false)
  let active = true
  async function load(): Promise<void> {
    busy.value = true; error.value = null
    try { const row = await read(); if (active) { name.value = row.name; welcome.value = row.welcomeChannelId; revision.value = row.revision } }
    catch (cause) { if (active) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить настройки.' }
    finally { if (active) busy.value = false }
  }
  async function save(availableChannels: string[]): Promise<void> {
    if (!active || busy.value || !revision.value) return
    saved.value = false; error.value = null
    if (!validGuildName(name.value.trim())) { error.value = 'Название: от 1 до 80 символов, без переводов строк.'; return }
    if (welcome.value !== null && !availableChannels.includes(welcome.value)) { error.value = 'Выберите доступный текстовый канал или выключите приветствия.'; return }
    busy.value = true
    try {
      const row = await write({ name: name.value.trim(), expected_revision: revision.value, welcome_channel_id: welcome.value })
      if (active) { name.value = row.name; revision.value = row.revision; welcome.value = row.welcomeChannelId; saved.value = true; void guildProfile.refresh(row.revision) }
    } catch (cause) {
      if (!active) return
      error.value = cause instanceof Error ? cause.message : 'Не удалось сохранить настройки.'
      if (cause instanceof GuildSettingsError && cause.status === 409) {
        try { const row = await read(); if (active) revision.value = row.revision }
        catch { if (active) { revision.value = 0; error.value += ' Перечитайте настройки перед повторной попыткой.' } }
      }
    } finally { if (active) busy.value = false }
  }
  return { name, welcome, revision, busy, error, saved, load, save, dispose: () => { active = false } }
}
