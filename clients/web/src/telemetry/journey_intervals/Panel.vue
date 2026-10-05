<script setup lang="ts">
import { journeyRecorder,stopJourneyRun } from './runtime'
const labels={voice_connect:'Нажатие → подключение к голосу',send_ack:'Начало отправки → подтверждение API',accepted_rendered:'Подтверждение API → обновление DOM',select_first_frame:'Выбор просмотра → первый кадр',reconnect_recovered:'Начало reconnect → восстановление'}
function download():void {
  const report={schema:'boohtacord.synthetic-journeys.v1',clock:'client_monotonic',observations:journeyRecorder.rows.value.map(({kind,durationMs,outcome})=>({kind,durationMs,outcome}))}
  const url=URL.createObjectURL(new Blob([JSON.stringify(report,null,2)],{type:'application/json'})),link=document.createElement('a')
  link.href=url;link.download='boohtacord-synthetic-journeys.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000)
}
</script>
<template>
  <section aria-labelledby="journey-title"><h3 id="journey-title">Синтетический пользовательский прогон</h3>
    <p>Локальные интервалы браузера, до 5 минут и 50 наблюдений. Запустите прогон и выполните нужные действия в тестовом аккаунте. Это отдельные измерения; они не заменяют утверждённые p95 и проверки оборудования.</p>
    <button type="button" :disabled="journeyRecorder.active.value" @click="journeyRecorder.start">Начать локальный прогон</button>
    <button v-if="journeyRecorder.active.value" type="button" @click="stopJourneyRun">Завершить прогон</button>
    <table><thead><tr><th>Интервал</th><th>Время, мс</th><th>Результат</th></tr></thead><tbody><tr v-for="(row,index) in journeyRecorder.rows.value" :key="index"><td>{{ labels[row.kind] }}</td><td>{{ row.durationMs }}</td><td>{{ row.outcome }}</td></tr></tbody></table>
    <p v-if="!journeyRecorder.rows.value.length">Нет наблюдений. Неизмеренные интервалы не считаются нулевыми.</p>
    <button type="button" :disabled="!journeyRecorder.rows.value.length" @click="download">Скачать локальные интервалы</button>
  </section>
</template>
