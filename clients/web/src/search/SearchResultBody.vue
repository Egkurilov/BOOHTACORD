<script setup lang="ts">
import { computed } from 'vue'
import { formatMessage, type MessageSpan } from '../conversation/message_format'

const props = defineProps<{ body: string; query: string }>()
const blocks = computed(() => formatMessage(props.body))
function parts(span: MessageSpan): { value: string; match: boolean }[] {
  const needle = props.query.trim().toLocaleLowerCase()
  if (!needle) return [{ value: span.value, match: false }]
  const result: { value: string; match: boolean }[] = []
  const lower = span.value.toLocaleLowerCase()
  let start = 0
  for (let index = lower.indexOf(needle); index !== -1; index = lower.indexOf(needle, start)) {
    if (index > start) result.push({ value: span.value.slice(start, index), match: false })
    result.push({ value: span.value.slice(index, index + needle.length), match: true })
    start = index + needle.length
  }
  if (start < span.value.length) result.push({ value: span.value.slice(start), match: false })
  return result
}
</script>

<template>
  <div class="search-result-body">
    <template v-for="(block, blockIndex) in blocks" :key="blockIndex">
      <pre v-if="block.kind === 'CODE_BLOCK'" class="message-code"><code>{{ block.value }}</code></pre>
      <p v-else>
        <template v-for="(span, spanIndex) in block.spans" :key="spanIndex">
          <component :is="span.kind === 'LINK' ? 'a' : span.kind === 'BOLD' ? 'strong' : span.kind === 'ITALIC' ? 'em' : span.kind === 'CODE' ? 'code' : 'span'" :href="span.kind === 'LINK' ? span.href : undefined" :target="span.kind === 'LINK' ? '_blank' : undefined" :rel="span.kind === 'LINK' ? 'noopener noreferrer' : undefined"><template v-for="(part, partIndex) in parts(span)" :key="partIndex"><mark v-if="part.match">{{ part.value }}</mark><template v-else>{{ part.value }}</template></template></component>
        </template>
      </p>
    </template>
  </div>
</template>
