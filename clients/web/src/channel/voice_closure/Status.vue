<script setup lang="ts">
import { onBeforeUnmount,ref,watch } from 'vue'
import { inspectClosure,type Closure } from './client'
const props=defineProps<{channelId:string}>()
const result=ref<Closure|null>(null),error=ref(''),busy=ref(false),now=ref(Date.now())
let generation=0,abort:AbortController|null=null,timer:ReturnType<typeof setInterval>|null=null
async function refresh():Promise<void> {
  abort?.abort();abort=new AbortController();const current=++generation;busy.value=true
  try {const value=await inspectClosure(props.channelId,abort.signal);if(current===generation){result.value=value;error.value=''}}
  catch(cause){if(current===generation) error.value=cause instanceof Error?cause.message:'Состояние недоступно.'}
  finally {if(current===generation) busy.value=false}
}
watch(()=>props.channelId,()=>{result.value=null;void refresh()},{immediate:true})
timer=setInterval(()=>{now.value=Date.now()},1000)
onBeforeUnmount(()=>{generation++;abort?.abort();if(timer) clearInterval(timer)})
</script>
<template>
  <section role="region" aria-label="Серверные фазы закрытия голосовой комнаты">
    <ol v-if="result">
      <li>Вход: {{ result.admission_closed ? 'закрыт' : 'открыт' }}</li>
      <li>Отзыв в SFU: {{ result.pending_revocations ? `ожидается (${result.pending_revocations})` : 'очередь завершена' }}</li>
      <li>Комната пуста: {{ result.room_empty === null ? 'не подтверждено' : result.room_empty ? 'подтверждено SFU' : 'ещё есть участники' }}</li>
      <li>Завершение: {{ result.phase === 'finalized' ? 'подтверждено сервером' : 'ожидается' }}</li>
    </ol>
    <p v-if="result?.detail" role="status">SFU недоступен. Пустая комната и завершение не подтверждены.</p>
    <p v-if="result" role="status">Проверено {{ Math.max(0,Math.floor((now-Date.parse(result.checked_at))/1000)) }} с назад. Повторная проверка не изменяет комнату.</p>
    <p v-if="error" role="alert">{{ error }}</p>
    <button type="button" :disabled="busy" @click="refresh">{{ busy ? 'Проверяем…' : 'Проверить серверные фазы' }}</button>
  </section>
</template>
