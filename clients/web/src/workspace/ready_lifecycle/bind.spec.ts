import { expect, it, vi } from 'vitest'
const hooks = vi.hoisted(() => ({ mount: vi.fn(), unmount: vi.fn(), observe: vi.fn() }))
vi.mock('vue', () => ({ onMounted: hooks.mount, onBeforeUnmount: hooks.unmount }))
vi.mock('../../telemetry/observe_render/workspace', () => ({ observeWorkspace: hooks.observe }))
import { bindWorkspaceReady } from './bind'

it('preserves startup, refresh, readiness cancellation and teardown ordering', async () => {
  const start = vi.fn(), refresh = vi.fn(async () => undefined), stop = vi.fn(), failed = vi.fn(() => false)
  bindWorkspaceReady({ start, refresh, stop, failed })
  expect(start).not.toHaveBeenCalled()
  hooks.mount.mock.calls[0][0]()
  expect(start).toHaveBeenCalledOnce()
  const [, load, active, failure] = hooks.observe.mock.calls[0]
  await load()
  expect(refresh).toHaveBeenCalledOnce()
  expect(active()).toBe(true)
  expect(failure).toBe(failed)
  hooks.unmount.mock.calls[0][0]()
  expect(active()).toBe(false)
  expect(stop).toHaveBeenCalledOnce()
})
