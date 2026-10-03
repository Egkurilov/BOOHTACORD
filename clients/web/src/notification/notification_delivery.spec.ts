import { describe, expect, it, vi } from 'vitest'

import { createNotificationDelivery, type NotificationRuntime } from './notification_delivery'

function fixture(initial: NotificationPermission = 'default') {
  const values = new Map<string, string>()
  const show = vi.fn()
  const requestPermission = vi.fn(async () => 'granted' as NotificationPermission)
  let permission = initial
  let tail = Promise.resolve()
  const runtime: NotificationRuntime = {
    permission: () => permission,
    requestPermission: async () => { permission = await requestPermission(); return permission },
    show,
    storage: { getItem: (key) => values.get(key) ?? null, setItem: (key, value) => { values.set(key, value) } },
    lock: async (_key, action) => {
      const previous = tail
      let release!: () => void
      tail = new Promise<void>((resolve) => { release = resolve })
      await previous
      try { return await action() } finally { release() }
    },
  }
  return { runtime, show, requestPermission, setPermission: (next: NotificationPermission) => { permission = next } }
}

describe('browser notification delivery', () => {
  it('requests permission only after explicit enable and handles disable/revocation', async () => {
    const value = fixture()
    const delivery = createNotificationDelivery('account-a', value.runtime)
    await delivery.deliver('event-1', 'Новое личное сообщение.')
    expect(value.requestPermission).not.toHaveBeenCalled()
    expect(value.show).not.toHaveBeenCalled()
    expect(await delivery.enable()).toBe(true)
    await delivery.deliver('event-1', 'Новое личное сообщение.')
    expect(value.show).toHaveBeenCalledOnce()
    delivery.disable()
    await delivery.deliver('event-2', 'Новое личное сообщение.')
    expect(value.show).toHaveBeenCalledOnce()
    value.setPermission('denied')
    expect(delivery.permission()).toBe('denied')
  })

  it('delivers one notification across two tabs for the same event', async () => {
    const value = fixture('granted')
    const first = createNotificationDelivery('account-a', value.runtime)
    const second = createNotificationDelivery('account-a', value.runtime)
    await first.enable()
    await Promise.all([first.deliver('event-1', 'Новое личное сообщение.'), second.deliver('event-1', 'Новое личное сообщение.')])
    expect(value.show).toHaveBeenCalledOnce()
    expect(value.show.mock.calls[0]?.[0]).toBe('BOOHTACORD')
    expect(value.show.mock.calls[0]?.[1]).toMatchObject({ body: 'Новое личное сообщение.' })
  })

  it('retries an event when showing its notification throws', async () => {
    const value = fixture('granted')
    const delivery = createNotificationDelivery('account-a', value.runtime)
    await delivery.enable()
    value.show.mockImplementationOnce(() => { throw new Error('notification unavailable') })

    await expect(delivery.deliver('event-1', 'Новое личное сообщение.')).rejects.toThrow('notification unavailable')
    await delivery.deliver('event-1', 'Новое личное сообщение.')
    await delivery.deliver('event-1', 'Новое личное сообщение.')

    expect(value.show).toHaveBeenCalledTimes(2)
    expect(value.show.mock.calls[1]?.[1]).toMatchObject({ body: 'Новое личное сообщение.', tag: 'event-1' })
  })

  it('stays unavailable without a browser API or cross-tab lock', async () => {
    const value = fixture()
    const runtime = { ...value.runtime, lock: null }
    const delivery = createNotificationDelivery('account-a', runtime)
    expect(delivery.available()).toBe(false)
    expect(await delivery.enable()).toBe(false)
    expect(value.requestPermission).not.toHaveBeenCalled()
    expect(createNotificationDelivery('account-a', { ...value.runtime, permission: () => 'unavailable' }).available()).toBe(false)
  })

  it('does not enable delivery when permission is denied', async () => {
    const value = fixture()
    value.requestPermission.mockResolvedValue('denied')
    const delivery = createNotificationDelivery('account-a', value.runtime)
    expect(await delivery.enable()).toBe(false)
    expect(delivery.enabled()).toBe(false)
    await delivery.deliver('event-1', 'Новое личное сообщение.')
    expect(value.show).not.toHaveBeenCalled()
  })

  it('does not save a permission granted after the account is stopped', async () => {
    const value = fixture()
    let grant!: (permission: NotificationPermission) => void
    value.requestPermission.mockImplementation(() => new Promise<NotificationPermission>((resolve) => { grant = resolve }))
    const delivery = createNotificationDelivery('account-a', value.runtime)
    const enabling = delivery.enable()

    delivery.cancel()
    grant('granted')
    expect(await enabling).toBe(false)
    expect(value.runtime.storage?.getItem('boohtacord:notification:account-a:enabled')).toBeNull()
    await delivery.deliver('event-1', 'Новое личное сообщение.')
    expect(value.show).not.toHaveBeenCalled()
  })
})
