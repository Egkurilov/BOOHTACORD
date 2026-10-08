<script setup lang="ts">
import { browserScreenCaptureCapabilities } from './screen_capture_capabilities'

const capabilities = browserScreenCaptureCapabilities()
const video = capabilities.video === 'available' ? 'доступен в браузере' : 'недоступен в этом браузере'
</script>

<template>
  <div>
    <dl class="screen-share-capabilities">
      <div><dt>Просмотр</dt><dd>Доступен в голосовой комнате</dd></div>
      <div><dt>Поддержка до выбора источника</dt><dd>Видео: {{ video }}</dd></div>
      <div><dt>Звук до выбора источника</dt><dd>Неизвестно</dd></div>
    </dl>
    <p class="screen-share-capabilities__note">
      Звук определяется после выбора источника по фактически полученной дорожке; выбранный источник может не передать аудио. Игровой звук не гарантируется.
    </p>
  </div>
</template>
