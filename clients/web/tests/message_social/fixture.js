import { createApp,h,ref } from 'vue'
import { createPinia } from 'pinia'
import MessageItem from '/src/conversation/MessageItem.vue'
import SearchPanel from '/src/search/SearchPanel.vue'
import { useSearchTargetStore } from '/src/search/search_target_store.ts'
import { notifySocialRecovery } from '/src/conversation/reactions/hints.ts'
import { clearAuthenticatedState } from '/src/identity/clear_authenticated_state.ts'
import '/src/style.css'
const conversationId='11111111-1111-4111-8111-111111111111',messageId='22222222-2222-4222-8222-222222222222',authorId='33333333-3333-4333-8333-333333333333'
const pinia=createPinia(),kind=ref('CHANNEL'),live=ref(true),search=ref(false),target=useSearchTargetStore(pinia)
createApp({render:()=>h('main',[
 h('button',{onClick:()=>{kind.value='CHANNEL'}},'Открыть TEXT'),h('button',{onClick:()=>{kind.value='DIRECT_MESSAGE'}},'Открыть DM'),
 h('button',{onClick:()=>{search.value=true}},'Открыть поиск'),h('button',{onClick:()=>notifySocialRecovery()},'Переподключиться'),
 h('button',{onClick:()=>{live.value=false;search.value=false;clearAuthenticatedState(pinia)}},'Завершить сессию'),
 live.value?h(MessageItem,{message:{id:messageId,authorId,clientMessageId:'44444444-4444-4444-8444-444444444444',body:'Synthetic message',createdAt:'2026-10-09T12:00:00Z',revision:1,deleted:false,...(kind.value==='CHANNEL'?{channelId:conversationId}:{directMessageId:conversationId})},canEdit:false,canDelete:false}):null,
 live.value&&search.value?h(SearchPanel,{currentConversation:{id:conversationId,kind:kind.value,label:'Current'},channelLabels:{},directMessageLabels:{},onClose:()=>{search.value=false}}):null,
 h('output',{'data-testid':'target'},target.target?`${target.target.kind}:${target.target.conversationId}:${target.target.messageId}`:''),
])}).use(pinia).mount('#app')
