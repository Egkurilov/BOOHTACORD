<script setup lang="ts">
import { computed,onBeforeUnmount,onMounted,ref } from 'vue'
import { inspectReadiness,type Readiness } from './client'
import JourneyPanel from '../../telemetry/journey_intervals/Panel.vue'
const result=ref<Readiness|null>(null),error=ref(''),busy=ref(false),now=ref(Date.now())
let abort:AbortController|null=null,generation=0,timer:ReturnType<typeof setInterval>|null=null
const age=computed(()=>result.value?Math.max(0,Math.floor((now.value-Date.parse(result.value.checked_at))/1000)):null)
const fresh=computed(()=>!error.value&&age.value!==null&&age.value<=15)
const bytes=(value:number|null|undefined)=>value===null||value===undefined?'Неизвестно':`${(value/1024/1024).toFixed(1)} МиБ`
async function refresh():Promise<void> {
  abort?.abort();abort=new AbortController();const current=++generation;busy.value=true
  try {const value=await inspectReadiness(abort.signal);if(current===generation){result.value=value;error.value='';now.value=Date.now()}}
  catch(cause){if(current===generation) error.value=cause instanceof Error?cause.message:'Проверка недоступна.'}
  finally{if(current===generation) busy.value=false}
}
onMounted(()=>{void refresh();timer=setInterval(()=>{now.value=Date.now()},1000)})
onBeforeUnmount(()=>{generation++;abort?.abort();if(timer) clearInterval(timer)})
</script>
<template>
  <section aria-labelledby="readiness-title">
    <h2 id="readiness-title">Готовность сервисов</h2>
    <p>Публичный health подтверждает только работу API. Здесь проверяются приватные зависимости и запас для следующей загрузки.</p>
    <p role="status">{{ fresh ? result?.status === 'ready' ? 'Сервисы готовы' : 'Есть проблемы готовности' : 'Нет свежего подтверждения готовности' }}</p>
    <p v-if="age !== null">Возраст проверки: {{ age }} с. После 15 с результат считается устаревшим.</p>
    <dl v-if="result"><template v-for="(probe,key) in {database:result.database,sfu:result.sfu,storage:result.storage}" :key="key"><dt>{{ key === 'database' ? 'PostgreSQL' : key === 'sfu' ? 'LiveKit' : 'Хранилище' }}</dt><dd>{{ fresh ? probe.status === 'ready' ? 'готов' : probe.status === 'failed' ? 'ошибка' : 'неизвестно' : 'устарело' }}{{ probe.reason ? ` (${probe.reason})` : '' }}</dd></template></dl>
    <dl v-if="result"><dt>Свободно</dt><dd>{{ bytes(result.storage.available_bytes) }}</dd><dt>Всего</dt><dd>{{ bytes(result.storage.total_bytes) }}</dd><dt>Зарезервировано загрузками</dt><dd>{{ bytes(result.storage.reserved_bytes) }}</dd><dt>Защищённый запас</dt><dd>{{ bytes(result.storage.protected_bytes) }}</dd><dt>Доступно после резервов</dt><dd>{{ bytes(result.storage.headroom_bytes) }}</dd><dt>Ожидают отзыва в SFU</dt><dd>{{ result.database.pending_revocations ?? 'Неизвестно' }}</dd></dl>
    <button type="button" :disabled="busy" @click="refresh">{{ busy ? 'Проверяем…' : 'Обновить проверку' }}</button>
    <p v-if="error" role="alert">{{ error }}</p>
    <JourneyPanel />
  </section>
</template>
