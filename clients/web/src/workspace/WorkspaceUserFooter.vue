<script setup lang="ts">
import { avatarInitials } from '../design/avatar_initials'
import { avatarBackground } from '../design/avatar_color'
defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR'; displayName?: string; avatarURL?: string; accountID?: string }>()
const emit = defineEmits<{ openSettings: []; openProfile: [] }>()
</script>

<template>
  <footer class="user-footer">
    <button class="user-footer-profile" type="button" aria-label="Открыть настройки профиля" @click="emit('openProfile')">
      <img v-if="avatarURL" class="user-footer-avatar" :src="avatarURL" alt="">
      <span v-else class="user-footer-avatar" :style="{ backgroundColor: avatarBackground(accountID ?? displayName ?? 'Вы') }" aria-hidden="true">{{ avatarInitials(displayName, 'В') }}</span>
      <span class="username"><span class="user-footer-name">{{ displayName || 'Профиль' }}</span><small>{{ role === 'ADMINISTRATOR' ? 'Администратор' : 'Участник' }}</small></span>
    </button>
    <button class="user-footer-settings" type="button" aria-label="Настройки аудио" title="Настройки аудио" @click="emit('openSettings')">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm8 4a7.8 7.8 0 0 0-.1-1.2l2-1.5-2-3.5-2.4 1a8.6 8.6 0 0 0-2.1-1.2L15 3h-4l-.4 2.8a8.6 8.6 0 0 0-2.1 1.2l-2.4-1-2 3.5 2 1.5A7.8 7.8 0 0 0 6 12c0 .4 0 .8.1 1.2l-2 1.5 2 3.5 2.4-1a8.6 8.6 0 0 0 2.1 1.2L11 21h4l.4-2.8a8.6 8.6 0 0 0 2.1-1.2l2.4 1 2-3.5-2-1.5c.1-.4.1-.8.1-1.2Z" /></svg>
    </button>
  </footer>
</template>
