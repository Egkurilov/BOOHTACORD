import { describe, expect, it, vi } from 'vitest'

import { apiBaseUrl } from '../config/runtime'
import { createMaintenanceRealtime, type MaintenanceEvents } from './maintenance_realtime'

class EventSourceStub implements MaintenanceEvents {
  onmessage: ((event: { data: string }) => void) | null = null
  onerror: (() => void) | null = null
  close = vi.fn()
}

describe('maintenance realtime stream', () => {
  it('opens one public SSE stream and applies valid status snapshots', () => {
    const source = new EventSourceStub()
    const open = vi.fn(() => source)
    const maintenance = createMaintenanceRealtime(open)

    maintenance.start()
    maintenance.start()

    expect(open).toHaveBeenCalledTimes(1)
    expect(open).toHaveBeenCalledWith(`${apiBaseUrl}/maintenance/events`)
    expect(maintenance.active.value).toBe(false)

    source.onmessage?.({ data: '{"active":true}' })
    expect(maintenance.active.value).toBe(true)
    source.onmessage?.({ data: '{"active":"true"}' })
    expect(maintenance.active.value).toBe(true)
  })

  it('keeps the last known state while EventSource reconnects and closes on stop', () => {
    const source = new EventSourceStub()
    const maintenance = createMaintenanceRealtime(() => source)

    maintenance.start()
    source.onmessage?.({ data: '{"active":true}' })
    source.onerror?.()
    expect(maintenance.active.value).toBe(true)
    expect(source.close).not.toHaveBeenCalled()

    maintenance.stop()
    expect(source.close).toHaveBeenCalledOnce()
  })
})
