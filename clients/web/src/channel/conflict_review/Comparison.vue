<script setup lang="ts">
defineProps<{before:string;current:string|null;proposed:string;ready:boolean;busy?:boolean}>()
defineEmits<{apply:[];discard:[];refresh:[]}>()
</script>
<template>
  <section role="region" aria-label="Сравнение конфликтующих изменений" class="admin-conflict-review">
    <h4>Другой администратор изменил данные</h4>
    <dl><dt>Было</dt><dd>{{ before }}</dd><dt>Теперь на сервере</dt><dd>{{ current ?? 'Нужно обновить данные' }}</dd><dt>Ваше изменение</dt><dd>{{ proposed }}</dd></dl>
    <p>Повторная запись возможна только после проверки актуальных данных.</p>
    <button type="button" :disabled="busy" @click="$emit('refresh')">Обновить сравнение</button>
    <button type="button" :disabled="busy || !ready" @click="$emit('discard')">Принять серверные данные</button>
    <button type="button" :disabled="busy || !ready" @click="$emit('apply')">Проверено — применить моё изменение</button>
  </section>
</template>

<style scoped>
.admin-conflict-review > button {
  min-height: 36px;
  padding: 4px 10px;
}
</style>
