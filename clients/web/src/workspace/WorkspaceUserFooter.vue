<script setup lang="ts">
import { avatarInitials } from '../design/avatar_initials'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR'; displayName?: string; avatarURL?: string; accountID?: string }>()
const emit = defineEmits<{ openSettings: []; openProfile: [] }>()
</script>

<template>
  <footer class="user-footer">
    <button class="user-footer-profile" type="button" aria-label="Открыть настройки профиля" @click="emit('openProfile')">
      <img v-if="avatarURL" class="user-footer-avatar" :src="avatarURL" alt="">
      <span v-else class="user-footer-avatar" :style="{ backgroundColor: avatarBackground(accountID ?? displayName ?? 'Вы'), color: avatarForeground(accountID ?? displayName ?? 'Вы') }" aria-hidden="true">{{ avatarInitials(displayName, 'В') }}</span>
      <span class="username"><span class="user-footer-name">{{ displayName || 'Профиль' }}</span><small>{{ role === 'ADMINISTRATOR' ? 'Администратор' : 'Участник' }}</small></span>
    </button>
    <button class="user-footer-settings" type="button" aria-label="Настройки аудио" title="Настройки аудио" @click="emit('openSettings')">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 3 1-1h4l1 3 3 1 3 1v4l-2 2 1 3-3 3-3-1-2 2H8l-1-3-3-1-2-2 1-4 3-1 1-3Z" /><circle cx="12" cy="11" r="3" /></svg>
    </button>
  </footer>
</template>
