<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { kickVoiceParticipant } from '../identity/admin_directory_client'
import { loadMember, type GuildMember } from '../identity/profile_client'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import { focusMemberPopover } from './member_popover_focus'

const props = defineProps<{ memberID: string; self: boolean; viewerRole: 'MEMBER' | 'ADMINISTRATOR'; sameVoice: boolean; volume: number; top: number; modal: boolean }>()
const emit = defineEmits<{ close: []; openDM: [userID: string]; setVolume: [volume: number] }>()
const member = ref<GuildMember | null>(null); const loading = ref(true); const error = ref<string | null>(null); const status = ref<string | null>(null)
const panel = ref<HTMLElement | null>(null)
async function load(): Promise<void> { try { member.value = await loadMember(props.memberID) } catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить профиль участника.' } finally { loading.value = false; await nextTick(); focusMemberPopover(panel.value, props.modal) } }
function escape(event: KeyboardEvent): void { if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); emit('close') } }
async function kick(): Promise<void> {
  if (!window.confirm('Отключить участника от голосового канала?')) return
  try { const result = await kickVoiceParticipant(props.memberID); status.value = result.revoked_leases ? 'Подключение отозвано.' : 'Активное голосовое подключение не найдено.' }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось отключить участника.' }
}
onMounted(() => { document.addEventListener('keydown', escape); if (props.modal) panel.value?.focus(); void load() })
onBeforeUnmount(() => document.removeEventListener('keydown', escape))
</script>

<template>
  <section ref="panel" class="member-popover" role="dialog" :aria-modal="props.modal ? 'true' : 'false'" aria-label="Профиль участника" data-testid="member-popover" tabindex="-1" :style="props.modal ? undefined : { top: `${props.top}px` }">
    <header><span>Профиль участника</span><button type="button" aria-label="Закрыть профиль" @click="emit('close')">×</button></header>
    <p v-if="loading" class="state" aria-live="polite">Загружаем профиль…</p><p v-else-if="error" class="state state-error" role="alert">{{ error }}</p>
    <template v-else-if="member">
      <div class="member-popover-identity" :data-presence="member.presence"><span class="member-popover-avatar-wrap"><img v-if="member.avatar_url" :src="member.avatar_url" alt="" class="member-popover-avatar"><span v-else class="member-popover-avatar member-popover-avatar--empty" :style="{ backgroundColor: avatarBackground(props.memberID), color: avatarForeground(props.memberID) }">{{ avatarInitials(member.display_name) }}</span><span class="member-popover-avatar-presence" aria-hidden="true"></span></span><div><h2 :title="member.display_name">{{ member.display_name }}</h2><p>@{{ member.login }}</p><small>{{ member.role === 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь' }}</small><small class="member-popover-presence">{{ member.presence === 'online' ? 'В сети' : member.presence === 'offline' ? 'Не в сети' : 'Статус неизвестен' }}</small></div></div>
      <div class="member-popover-actions"><button v-if="!props.self" type="button" @click="emit('openDM', member.user_id)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M16 8v6a2 2 0 0 0 4 0v-2a8 8 0 1 0-3 6"/></svg>Написать сообщение</button><button v-if="props.viewerRole === 'ADMINISTRATOR' && props.sameVoice && !props.self" type="button" @click="kick">Отключить от голоса</button></div>
      <label v-if="props.sameVoice" class="member-volume">Громкость участника <output>{{ props.volume }}%</output><input type="range" min="0" max="200" step="1" :value="props.volume" @input="emit('setVolume', Number(($event.target as HTMLInputElement).value))"></label>
      <p v-if="status" class="member-popover-status" aria-live="polite">{{ status }}</p>
    </template>
  </section>
</template>
