<script setup lang="ts">
defineProps<{ pending: boolean; confirm: boolean }>()
defineEmits<{ generate: []; replace: []; keep: [] }>()
</script>

<template>
  <div class="authentication-password-generation">
    <button class="authentication-password-generate" type="button" :disabled="pending" @click="$emit('generate')">Сгенерировать пароль</button>
    <template v-if="confirm">
      <p id="password-replacement-question" class="authentication-password-confirm" role="alert">Заменить введённый пароль сгенерированным?</p>
      <div class="authentication-password-confirm-actions" role="group" aria-labelledby="password-replacement-question">
        <button type="button" :disabled="pending" @click="$emit('replace')">Заменить</button>
        <button type="button" :disabled="pending" @click="$emit('keep')">Оставить</button>
      </div>
    </template>
  </div>
</template>
