<script setup lang="ts">
defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR' }>()
const emit = defineEmits<{ openSettings: [] }>()
</script>

<template>
  <footer class="user-footer">
    <span class="user-footer-avatar" aria-hidden="true">В</span>
    <div class="username">
      <p>Вы</p>
      <small>{{ role === 'ADMINISTRATOR' ? 'Администратор' : 'Участник' }}</small>
    </div>
    <button class="user-footer-settings" type="button" aria-label="Настройки аудио" title="Настройки аудио" @click="emit('openSettings')">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm8 4a7.8 7.8 0 0 0-.1-1.2l2-1.5-2-3.5-2.4 1a8.6 8.6 0 0 0-2.1-1.2L15 3h-4l-.4 2.8a8.6 8.6 0 0 0-2.1 1.2l-2.4-1-2 3.5 2 1.5A7.8 7.8 0 0 0 6 12c0 .4 0 .8.1 1.2l-2 1.5 2 3.5 2.4-1a8.6 8.6 0 0 0 2.1 1.2L11 21h4l.4-2.8a8.6 8.6 0 0 0 2.1-1.2l2.4 1 2-3.5-2-1.5c.1-.4.1-.8.1-1.2Z" /></svg>
    </button>
  </footer>
</template>
