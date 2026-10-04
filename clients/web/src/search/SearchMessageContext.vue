<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, watch } from 'vue'
import MessageBody from '../conversation/message_body/MessageBody.vue'
import TextMessageAttachments from '../conversation/TextMessageAttachments.vue'
import { loadMessagePage, type TextMessage } from '../conversation/message_client'
import DirectMessageAttachments from '../direct_message/DirectMessageAttachments.vue'
import { loadDirectMessageHistory, type DirectMessageHistoryItem } from '../direct_message/direct_message_client'
import { useAuthorDirectory } from '../identity/author_directory'
import { createSearchContextController } from './search_context_controller'

const props = defineProps<{ kind: 'CHANNEL' | 'DIRECT_MESSAGE'; conversationId: string; messageId: string; heading?: string }>()
const emit = defineEmits<{ close: [] }>()
const authors = useAuthorDirectory()
const root = ref<HTMLElement | null>(null)
const context = createSearchContextController<TextMessage | DirectMessageHistoryItem>((id) => props.kind === 'CHANNEL'
  ? loadMessagePage(props.conversationId, undefined, undefined, id)
  : loadDirectMessageHistory(props.conversationId, undefined, undefined, id))
const { messages, status } = context

watch(() => [props.kind, props.conversationId, props.messageId], () => { void context.open(props.messageId) }, { immediate: true })
watch(messages, (items) => { for (const item of items) void authors.ensure(item.authorId) })
watch(status, (value) => { if (value === 'ready' || value === 'deleted') void nextTick(() => root.value?.querySelector<HTMLElement>('[data-search-anchor]')?.focus()) })
onBeforeUnmount(context.clear)
</script>

<template>
  <section ref="root" class="search-message-context" aria-labelledby="search-context-title" data-testid="search-message-context">
    <header class="search-context-header">
      <h3 id="search-context-title">{{ props.heading ?? 'Контекст найденного сообщения' }}</h3>
      <button type="button" @click="emit('close')">К последним сообщениям</button>
    </header>
    <p v-if="status === 'loading'" role="status">Открываем сообщение…</p>
    <p v-else-if="status === 'unavailable'" role="alert">Сообщение больше недоступно в этой беседе.</p>
    <p v-else-if="status === 'error'" role="alert">Не удалось открыть сообщение. Беседа могла стать недоступной. <button type="button" @click="context.open(props.messageId)">Повторить</button></p>
    <ol v-if="messages.length" class="search-context-list" aria-label="Найденное сообщение и предыдущие сообщения">
      <li v-for="message in messages" :key="message.id" :class="{ 'search-context-target': message.id === props.messageId }" :data-search-anchor="message.id === props.messageId ? '' : undefined" :aria-current="message.id === props.messageId ? 'location' : undefined" :tabindex="message.id === props.messageId ? -1 : undefined">
        <p class="message-meta">{{ authors.displayName(message.authorId) }} · {{ new Date(message.createdAt).toLocaleString('ru-RU') }}</p>
        <p v-if="message.deleted">Сообщение удалено.</p>
        <MessageBody v-else :body="message.body" />
        <TextMessageAttachments v-if="props.kind === 'CHANNEL' && !message.deleted" :channel-id="props.conversationId" :attachments="message.attachments" />
        <DirectMessageAttachments v-if="props.kind === 'DIRECT_MESSAGE' && !message.deleted" :direct-message-id="props.conversationId" :attachments="message.attachments" />
      </li>
    </ol>
  </section>
</template>
