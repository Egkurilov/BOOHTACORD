import { nextTick, ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { usePasswordResetResultFocus } from './password_reset_result_focus'

async function settle(): Promise<void> {
  await nextTick()
  await nextTick()
}

describe('password reset result focus', () => {
  it('focuses the result after success or a used-link transition', async () => {
    const visible = ref(false)
    const focus = vi.fn()
    const target = ref({ focus } as unknown as HTMLElement)
    usePasswordResetResultFocus(visible, target)
    await settle()
    expect(focus).not.toHaveBeenCalled()

    visible.value = true
    await settle()
    expect(focus).toHaveBeenCalledOnce()
  })

  it('focuses an initially invalid link after the result element mounts', async () => {
    const visible = ref(true)
    const focus = vi.fn()
    const target = ref<HTMLElement | null>(null)
    usePasswordResetResultFocus(visible, target)
    target.value = { focus } as unknown as HTMLElement
    await settle()
    expect(focus).toHaveBeenCalledOnce()
  })
})
