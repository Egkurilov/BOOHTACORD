<script setup lang="ts">
import { computed,ref } from 'vue'
import { useVoiceConnectionStore } from '../connection_store'
import { useTopologyStore } from '../../channel/topology_store'
import type { VoiceJoinMode } from '../livekit_gateway'
const emit=defineEmits<{confirm:[mode:VoiceJoinMode]}>()
const voice=useVoiceConnectionStore(),topology=useTopologyStore(),dialog=ref<HTMLDialogElement|null>(null)
const currentRoom=computed(()=>topology.topology?.categories.flatMap(c=>c.channels).find(c=>c.id===(voice.transferChannelId ?? voice.originControllerChannel))?.name ?? 'Другая комната (название недоступно)')
function confirm():void {dialog.value?.close();emit('confirm',voice.transferJoinMode)}
</script>
<template>
  <section aria-label="Перенос голосового подключения">
    <p role="status">Уже есть голосовое подключение: {{ currentRoom }}.</p>
    <p>Сессия входа остаётся общей. Управлять микрофоном и демонстрацией может одно окно.</p>
    <button class="gc-button gc-button--primary" type="button" @click="dialog?.showModal()">Перенести подключение сюда…</button>
    <dialog ref="dialog" aria-labelledby="transfer-title">
      <h3 id="transfer-title">Перенести голосовое подключение?</h3>
      <p>Текущее подключение: {{ currentRoom }}.</p>
      <p>В другом окне остановятся голос, просмотр и демонстрация экрана. Здесь будет создано новое подключение.</p>
      <p>Отмена сохранит текущее подключение.</p>
      <div class="voice-prejoin-actions">
        <button autofocus class="gc-button gc-button--secondary" type="button" @click="dialog?.close()">Отмена</button>
        <button class="gc-button gc-button--primary" type="button" @click="confirm">Перенести сюда</button>
      </div>
    </dialog>
  </section>
</template>
