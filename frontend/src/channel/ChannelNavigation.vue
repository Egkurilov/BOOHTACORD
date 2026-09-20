<script setup lang="ts">
import type { ChannelTopology, TopologyChannel } from './topology_client'

const props = defineProps<{
  activeVoiceChannelId?: string
  selectedChannelId?: string
  topology: ChannelTopology
}>()

const emit = defineEmits<{ select: [channel: TopologyChannel] }>()

function isConnectedVoice(channel: TopologyChannel): boolean { return channel.kind === 'VOICE' && channel.id === props.activeVoiceChannelId }
</script>

<template>
  <nav class="channel-navigation" aria-label="Категории и каналы">
    <section v-for="category in props.topology.categories" :key="category.id" class="channel-category">
      <h2>{{ category.name }}</h2>
      <p v-if="category.channels.length === 0" class="empty-category">Нет каналов</p>
      <button
        v-for="channel in category.channels"
        :key="channel.id"
        class="channel-button"
        :class="{ selected: props.selectedChannelId === channel.id, 'voice-connected': isConnectedVoice(channel) }"
        :aria-current="props.selectedChannelId === channel.id ? 'page' : undefined"
        type="button"
        @click="emit('select', channel)"
      >
        <span class="channel-icon" aria-hidden="true">
          <template v-if="channel.kind === 'TEXT'">#</template>
          <svg v-else viewBox="0 0 24 24"><path d="M8 10v4a4 4 0 0 0 8 0v-4M12 18v3M8 21h8M12 3a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z" /></svg>
        </span>
        <span class="channel-name">{{ channel.name }}</span>
        <span v-if="channel.admissionClosed" class="channel-state">Вход закрыт</span>
      </button>
    </section>
  </nav>
</template>
