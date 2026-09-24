import { describe, expect, it, vi } from 'vitest'

import { useMessageEditController, type EditResult } from './message_edit_controller'

const message = { body: 'Исходный текст', mentionUserIds: ['peer'], revision: 1 }

describe('message edit controller', () => {
  it('keeps the draft on conflict, waits for a newer revision and blocks duplicate saves', async () => {
    let finish!: (result: EditResult) => void
    const save = vi.fn().mockImplementationOnce(() => new Promise<EditResult>((resolve) => { finish = resolve }))
      .mockResolvedValueOnce({ kind: 'saved' })
    const refresh = vi.fn().mockResolvedValue({ revision: 2, deleted: false })
    const editor = useMessageEditController({ save, refresh })
    editor.begin(message)
    editor.body.value = 'Мой сохранённый черновик'
    const first = editor.submit()
    expect(editor.pending.value).toBe(true)
    await editor.submit()
    expect(save).toHaveBeenCalledOnce()
    finish({ kind: 'conflict', message: 'Конфликт версии.' })
    await first
    expect(editor.editing.value).toBe(true)
    expect(editor.body.value).toBe('Мой сохранённый черновик')
    expect(editor.needsRefresh.value).toBe(true)
    await editor.submit()
    expect(save).toHaveBeenCalledOnce()
    await editor.refreshVersion()
    expect(editor.baseRevision.value).toBe(2)
    expect(editor.needsRefresh.value).toBe(false)
    expect(editor.body.value).toBe('Мой сохранённый черновик')
    await editor.submit()
    expect(save).toHaveBeenNthCalledWith(2, 'Мой сохранённый черновик', ['peer'], 2)
    expect(editor.editing.value).toBe(false)
  })

  it('keeps the draft and permits retry after a network error', async () => {
    const save = vi.fn().mockResolvedValueOnce({ kind: 'error', message: 'Сеть недоступна.' }).mockResolvedValueOnce({ kind: 'saved' })
    const editor = useMessageEditController({ save, refresh: vi.fn() })
    editor.begin(message)
    editor.body.value = 'Изменённый текст'
    await editor.submit()
    expect(editor.editing.value).toBe(true)
    expect(editor.error.value).toContain('Сеть')
    await editor.submit()
    expect(editor.editing.value).toBe(false)
  })

  it('does not overwrite an unchanged or deleted server revision', async () => {
    const refresh = vi.fn().mockResolvedValueOnce({ revision: 1, deleted: false }).mockResolvedValueOnce({ revision: 2, deleted: true })
    const save = vi.fn().mockResolvedValue({ kind: 'conflict', message: 'Конфликт версии.' })
    const editor = useMessageEditController({ save, refresh })
    editor.begin(message)
    await editor.submit()
    await editor.refreshVersion()
    expect(editor.needsRefresh.value).toBe(true)
    await editor.refreshVersion()
    expect(editor.needsRefresh.value).toBe(true)
    expect(editor.body.value).toBe('Исходный текст')
  })
})
