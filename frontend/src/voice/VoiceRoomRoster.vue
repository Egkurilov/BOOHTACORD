<script setup lang="ts">
import { avatarBackground } from '../design/avatar_color'
import type { VoiceRoomRoster } from './voice_roster_client'

defineProps<{ roster: VoiceRoomRoster; compact?: boolean }>()

function initial(name: string): string { return Array.from(name.trim())[0]?.toLocaleUpperCase('ru-RU') || 'У' }
</script>

<template>
  <section class="voice-roster-preview" :class="{ 'voice-roster-preview--compact': compact }" :aria-label="`Сейчас в канале: ${roster.participants.length}`">
    <p class="voice-roster-heading">Сейчас в канале: {{ roster.participants.length }}</p>
    <ul v-if="roster.participants.length" class="voice-roster-members">
      <li v-for="member in roster.participants" :key="member.accountId" class="voice-roster-member">
        <span class="voice-member-avatar" :style="{ backgroundColor: avatarBackground(member.accountId) }" aria-hidden="true">{{ initial(member.displayName) }}</span>
        <span class="voice-member-name">{{ member.displayName }}</span>
        <span v-if="member.screenSharing" class="voice-roster-live" role="img" aria-label="Показывает экран" title="Показывает экран">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg><span>Идёт трансляция</span>
        </span>
      </li>
    </ul>
    <p v-else class="voice-roster-empty">Пока никого нет.</p>
  </section>
</template>
