import { ref } from 'vue'

export type EditResult = { kind: 'saved' } | { kind: 'conflict' | 'error' | 'stale'; message: string }
interface Revision { revision: number; deleted: boolean }
interface Editable { body: string; mentionUserIds?: string[]; revision: number }
interface EditPorts {
  save(body: string, mentionUserIds: string[], revision: number): Promise<EditResult>
  refresh(): Promise<Revision | null>
}

export function useMessageEditController(ports: EditPorts) {
  const editing = ref(false)
  const body = ref('')
  const mentionUserIds = ref<string[]>([])
  const baseRevision = ref(0)
  const pending = ref(false)
  const needsRefresh = ref(false)
  const error = ref<string | null>(null)
  const notice = ref<string | null>(null)

  function begin(message: Editable): void {
    if (pending.value) return
    body.value = message.body
    mentionUserIds.value = [...(message.mentionUserIds ?? [])]
    baseRevision.value = message.revision
    needsRefresh.value = false
    error.value = null
    notice.value = null
    editing.value = true
  }

  function cancel(): void { if (!pending.value) editing.value = false }

  async function submit(): Promise<void> {
    if (!editing.value || pending.value || needsRefresh.value) return
    if (!body.value) { error.value = 'Введите текст сообщения.'; return }
    pending.value = true
    error.value = null
    notice.value = null
    try {
      const result = await ports.save(body.value, [...mentionUserIds.value], baseRevision.value)
      if (result.kind === 'saved') editing.value = false
      else { error.value = result.message; needsRefresh.value = result.kind === 'conflict' }
    } catch { error.value = 'Не удалось сохранить сообщение. Повторите попытку.' }
    finally { pending.value = false }
  }

  async function refreshVersion(): Promise<void> {
    if (!editing.value || !needsRefresh.value || pending.value) return
    pending.value = true
    error.value = null
    try {
      const latest = await ports.refresh()
      if (latest?.deleted) error.value = 'Сообщение удалено. Ваш черновик сохранён для копирования.'
      else if (latest && latest.revision > baseRevision.value) {
        baseRevision.value = latest.revision
        needsRefresh.value = false
        notice.value = 'Версия обновлена. Проверьте свой текст перед повторным сохранением.'
      } else error.value = 'Не удалось получить новую версию сообщения. Повторите обновление.'
    } catch { error.value = 'Не удалось обновить сообщение. Повторите попытку.' }
    finally { pending.value = false }
  }

  return { editing, body, mentionUserIds, baseRevision, pending, needsRefresh, error, notice, begin, cancel, submit, refreshVersion }
}
