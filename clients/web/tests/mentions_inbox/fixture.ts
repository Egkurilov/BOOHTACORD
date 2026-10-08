import { createApp, defineComponent, h, ref } from 'vue'
import { createPinia } from 'pinia'
import SearchPanel from '../../src/search/SearchPanel.vue'
import type { MentionInboxItem } from '../../src/search/mentions_inbox_client'
import '../../src/style.css'

const target = ref<MentionInboxItem | null>(null)
createApp(defineComponent({
  setup() {
    return () => h('div', { class: 'app-frame' }, [
      h(SearchPanel, {
        currentConversation: null, channelLabels: {}, directMessageLabels: {},
        onOpenMention: (mention: MentionInboxItem) => { target.value = mention },
        onOpen: () => {}, onClose: () => {},
      }),
      h('output', { 'data-testid': 'opened-mention' }, target.value?.messageId ?? ''),
    ])
  },
})).use(createPinia()).mount('#app')
