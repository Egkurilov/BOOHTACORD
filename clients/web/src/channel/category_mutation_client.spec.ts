import { describe, expect, it, vi } from 'vitest'

import { CategoryMutationError, renameCategory, reorderCategories } from './category_mutation_client'

describe('category mutation client', () => {
  it('renames a category with the expected topology revision', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'category-1', name: 'Новая', revision: 9 })))
    await expect(renameCategory('category-1', 'Новая', 8, request)).resolves.toEqual({ id: 'category-1', name: 'Новая', revision: 9 })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/categories/category-1', {
      method: 'PATCH', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'Новая', expected_revision: 8 }),
    })
  })

  it('submits the complete category order and rejects duplicate IDs locally', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ revision: 10 })))
    await expect(reorderCategories(['category-2', 'category-1'], 9, request)).resolves.toEqual({ revision: 10 })
    expect(request).toHaveBeenCalledWith('/api/v1/admin/categories/order', {
      method: 'PUT', credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ expected_revision: 9, ids: ['category-2', 'category-1'] }),
    })
    await expect(reorderCategories(['category-1', 'category-1'], 9, request)).rejects.toThrow('порядок')
    expect(request).toHaveBeenCalledTimes(1)
  })

  it('keeps 409 distinct from validation and rejects malformed success responses', async () => {
    const conflict = vi.fn().mockResolvedValue(new Response(null, { status: 409 }))
    await expect(renameCategory('category-1', 'Новая', 8, conflict)).rejects.toMatchObject({ status: 409 })
    await expect(reorderCategories(['category-1'], 8, conflict)).rejects.toBeInstanceOf(CategoryMutationError)
    const malformed = vi.fn().mockResolvedValue(new Response(JSON.stringify({ revision: 0 })))
    await expect(reorderCategories(['category-1'], 8, malformed)).rejects.toThrow('некоррект')
  })
})
