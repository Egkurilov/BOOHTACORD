import { expect, it, vi } from 'vitest'
import { createNotificationDelivery, type NotificationRuntime } from '../notification_delivery'

it('uses current guild title with generic body, retaining account dedup and cancellation', async () => {
  const values = new Map<string, string>(), show = vi.fn()
  const runtime: NotificationRuntime = {
    permission: () => 'granted', requestPermission: async () => 'granted', show,
    storage: { getItem: k => values.get(k) ?? null, setItem: (k, v) => { values.set(k, v) } },
    lock: async (_, action) => action(),
  }
  let title = 'Длинная гильдия 🎉'
  const delivery = createNotificationDelivery('account', runtime, () => title)
  await delivery.enable()
  await delivery.deliver('one', 'Новое личное сообщение.')
  title = 'Новое имя'
  await delivery.deliver('two', 'Новое личное сообщение.')
  await delivery.deliver('two', 'Новое личное сообщение.')
  expect(show.mock.calls.map(c => c[0])).toEqual(['Длинная гильдия 🎉', 'Новое имя'])
  delivery.cancel()
  await delivery.deliver('three', 'Новое личное сообщение.')
  expect(show).toHaveBeenCalledTimes(2)
})
