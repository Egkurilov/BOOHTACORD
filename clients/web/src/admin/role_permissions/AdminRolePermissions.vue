<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { memberPermissionDefaults, permissionKeys, type PermissionKey, type PermissionValues } from '../../authorization/permission_keys'
import { loadRolePolicies, RolePolicyError, saveMemberPolicy, type RoleName, type RolePolicy } from './role_policy_client'
import { changed, copyPermissions, newlyGrantedDeletes } from './role_policy_editor'

const labels: Record<PermissionKey, string> = {
  'channel.text.create': 'Создавать текстовые каналы', 'channel.text.delete': 'Удалять текстовые каналы',
  'channel.voice.create': 'Создавать голосовые каналы', 'channel.voice.delete': 'Закрывать голосовые каналы',
  'category.create': 'Создавать категории', 'category.delete': 'Удалять пустые категории',
}
const roles = ref<RolePolicy[]>([]); const selected = ref<RoleName>('MEMBER'); const revision = ref(0)
const baseline = ref<PermissionValues>(memberPermissionDefaults()); const draft = ref<PermissionValues>(memberPermissionDefaults())
const loading = ref(false); const saving = ref(false); const error = ref(''); const status = ref('')
const current = computed(() => roles.value.find((role) => role.role === selected.value) ?? null)
const dirty = computed(() => selected.value === 'MEMBER' && changed(baseline.value, draft.value))
const displayed = computed(() => selected.value === 'MEMBER' ? draft.value : current.value?.permissions ?? draft.value)

async function load(resetDraft = true): Promise<void> {
  loading.value = true; error.value = ''; status.value = ''
  try {
    const page = await loadRolePolicies(); roles.value = page.roles; revision.value = page.revision
    const member = page.roles.find((role) => role.role === 'MEMBER')!; baseline.value = copyPermissions(member.permissions)
    if (resetDraft) draft.value = copyPermissions(member.permissions)
  } catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить настройки ролей.' }
  finally { loading.value = false }
}
function choose(role: RoleName): void {
  if (role === selected.value) return
  if (dirty.value && !window.confirm('Отменить несохранённые изменения?')) return
  selected.value = role; draft.value = copyPermissions(baseline.value); error.value = ''; status.value = ''
}
function reset(): void { draft.value = memberPermissionDefaults(); status.value = 'Загружены значения по умолчанию. Нажмите «Сохранить».' }
function cancel(): void { draft.value = copyPermissions(baseline.value); error.value = ''; status.value = '' }
async function save(): Promise<void> {
  const grants = newlyGrantedDeletes(baseline.value, draft.value)
  if (grants.length && !window.confirm('Выдать участникам права удаления? Это позволит удалять объекты гильдии.')) return
  saving.value = true; error.value = ''; status.value = ''
  try { await saveMemberPolicy(revision.value, draft.value, grants.length > 0); await load(true); status.value = 'Разрешения участников сохранены.' }
  catch (cause) {
    error.value = cause instanceof RolePolicyError && cause.status === 409 ? 'Настройки уже изменены другим администратором. Черновик сохранён; обновите данные или отмените изменения.' : cause instanceof Error ? cause.message : 'Не удалось сохранить разрешения.'
  } finally { saving.value = false }
}
function guard(event: BeforeUnloadEvent): void { if (dirty.value) event.preventDefault() }
onMounted(() => { window.addEventListener('beforeunload', guard); void load() })
onBeforeUnmount(() => window.removeEventListener('beforeunload', guard))
</script>

<template>
  <section class="role-permissions" aria-labelledby="role-permissions-title">
    <header class="admin-section-heading"><div><h2 id="role-permissions-title">Роли и разрешения</h2><p>Управление каналами для участников гильдии</p></div><button type="button" :disabled="loading" @click="load(false)">Обновить</button></header>
    <div class="role-selector" role="tablist" aria-label="Роль"><button v-for="role in roles" :key="role.role" type="button" role="tab" :aria-selected="selected === role.role" @click="choose(role.role)">{{ role.displayName }}</button></div>
    <p v-if="loading && !roles.length" class="state" aria-live="polite">Загружаем разрешения…</p>
    <fieldset v-else :disabled="selected === 'ADMINISTRATOR' || saving"><legend class="gc-sr-only">Разрешения роли</legend>
      <label v-for="key in permissionKeys" :key="key" class="role-permission-row"><input v-model="displayed[key]" type="checkbox" :disabled="selected === 'ADMINISTRATOR'"> <span>{{ labels[key] }}</span></label>
    </fieldset>
    <p v-if="selected === 'ADMINISTRATOR'" class="role-policy-note">Разрешения администратора обязательны и не изменяются.</p>
    <div v-else class="role-policy-actions"><button type="button" :disabled="saving" @click="reset">По умолчанию</button><button type="button" :disabled="!dirty || saving" @click="cancel">Отмена</button><button type="button" :disabled="!dirty || saving" @click="save">{{ saving ? 'Сохраняем…' : 'Сохранить' }}</button></div>
    <p v-if="status" class="admin-status" aria-live="polite">{{ status }}</p><p v-if="error" class="admin-error" role="alert">{{ error }}</p>
  </section>
</template>
