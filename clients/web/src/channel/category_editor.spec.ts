import { describe, expect, it, vi } from 'vitest'

import { createCategoryEditor } from './category_editor'
import type { TopologyCategory } from './topology_client'

const category = (id: string, name: string, position: number): TopologyCategory => ({ id, name, position, channels: [] })

describe('category editor', () => {
  it('preserves rename draft across a two-administrator revision conflict and retries with fresh revision', async () => {
    let revision = 7
    const categories = [category('cat-a', 'Старое', 0)]
    const changed = vi.fn()
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'cat-a', name: 'Новое', revision: 9 })))
    const editor = createCategoryEditor(() => ({ categories, revision, selectedCategoryId: 'cat-a' }), changed, request)
    editor.sync()
    editor.setRenameDraft('Новое')
    await expect(editor.rename()).resolves.toBe(false)
    expect(editor.renameDraft.value).toBe('Новое')
    expect(editor.conflict.value).toBe(true)
    expect(changed).toHaveBeenCalledTimes(1)
    await expect(editor.rename()).resolves.toBe(false)
    expect(request).toHaveBeenCalledTimes(1)
    revision = 8
    editor.sync()
    await expect(editor.rename()).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[1][1].body))).toEqual({ name: 'Новое', expected_revision: 8 })
    expect(changed).toHaveBeenCalledTimes(2)
  })

  it('moves the selected category by keyboard-safe adjacent steps using a complete order', async () => {
    const categories = [category('cat-c', 'C', 2), category('cat-a', 'A', 0), category('cat-b', 'B', 1)]
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ revision: 12 })))
    const editor = createCategoryEditor(() => ({ categories, revision: 11, selectedCategoryId: 'cat-b' }), vi.fn(), request)
    editor.sync()
    expect(editor.canMove(-1)).toBe(true)
    await expect(editor.move(-1)).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[0][1].body))).toEqual({ expected_revision: 11, ids: ['cat-b', 'cat-a', 'cat-c'] })
    expect(categories.map(({ id }) => id)).toEqual(['cat-c', 'cat-a', 'cat-b'])
  })

  it('disables boundary moves and rejects blank names without a request', async () => {
    const request = vi.fn()
    const editor = createCategoryEditor(() => ({ categories: [category('cat-a', 'A', 0)], revision: 5, selectedCategoryId: 'cat-a' }), vi.fn(), request)
    editor.sync()
    editor.setRenameDraft('  ')
    await expect(editor.rename()).resolves.toBe(false)
    expect(editor.error.value).toContain('имя')
    expect(editor.canMove(-1)).toBe(false)
    await expect(editor.move(-1)).resolves.toBe(false)
    expect(request).not.toHaveBeenCalled()
  })

  it('refreshes after a reorder conflict without changing the visible order', async () => {
    let revision = 4
    const categories = [category('cat-a', 'A', 0), category('cat-b', 'B', 1)]
    const changed = vi.fn()
    const request = vi.fn().mockResolvedValueOnce(new Response(null, { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ revision: 6 })))
    const editor = createCategoryEditor(() => ({ categories, revision, selectedCategoryId: 'cat-b' }), changed, request)
    editor.sync()
    await expect(editor.move(-1)).resolves.toBe(false)
    expect(editor.conflict.value).toBe(true)
    expect(editor.canMove(-1)).toBe(false)
    expect(categories.map(({ id }) => id)).toEqual(['cat-a', 'cat-b'])
    expect(changed).toHaveBeenCalledTimes(1)
    revision = 5
    editor.sync()
    await expect(editor.move(-1)).resolves.toBe(true)
    expect(JSON.parse(String(request.mock.calls[1][1].body))).toEqual({ expected_revision: 5, ids: ['cat-b', 'cat-a'] })
  })
})
