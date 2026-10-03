<script setup lang="ts">
import { onBeforeUnmount, onMounted, useId } from 'vue'

import { useConversationOverflowMenu } from './conversation_overflow_menu'

const props = withDefaults(defineProps<{ showMembers?: boolean; membersOpen?: boolean; menuLabel?: string }>(), {
  showMembers: false,
  membersOpen: false,
  menuLabel: 'Действия переписки',
})
const emit = defineEmits<{ search: []; toggleMembers: [] }>()
const menuId = useId()
const { expanded, root, trigger, menu, toggle, onOutside, onFocusOut, onKeys, openSearch, toggleMembers } =
  useConversationOverflowMenu(() => emit('search'), () => emit('toggleMembers'))

onMounted(() => document.addEventListener('pointerdown', onOutside))
onBeforeUnmount(() => document.removeEventListener('pointerdown', onOutside))
</script>

<template>
  <div ref="root" class="conversation-overflow" @keydown="onKeys" @focusout="onFocusOut">
    <button ref="trigger" class="header-action conversation-overflow__trigger" type="button"
      aria-label="Другие действия" aria-haspopup="menu" :aria-expanded="expanded"
      :aria-controls="menuId" @click="toggle">⋯</button>
    <div v-show="expanded" :id="menuId" ref="menu" class="conversation-overflow__menu" role="menu" :aria-label="props.menuLabel">
      <button type="button" role="menuitem" @click="openSearch">Найти сообщение</button>
      <button v-if="props.showMembers" type="button" role="menuitem" @click="toggleMembers">{{ props.membersOpen ? 'Скрыть участников' : 'Показать участников' }}</button>
    </div>
  </div>
</template>
