import { describe, expect, it, vi } from 'vitest'

import { StreamStartAlert } from './stream_start_alert'

const remote = (id: string) => ({ id, participantName: id, isLocal: false })
const local = (id: string) => ({ id, participantName: 'Ваш экран', isLocal: true })

describe('new remote screen announcement', () => {
  it('ignores existing and local streams, then signals each new remote start once', () => {
    const started = vi.fn()
    const alert = new StreamStartAlert(started)
    alert.observe([remote('alice'), local('self')], 'JOINING')
    alert.observe([remote('alice'), local('self')], 'CONNECTED')
    alert.observe([remote('alice'), local('self')], 'CONNECTED')
    alert.observe([remote('alice'), local('self'), local('second-local-track')], 'CONNECTED')
    expect(started).not.toHaveBeenCalled()

    alert.observe([remote('alice'), remote('bob'), local('self')], 'CONNECTED')
    alert.observe([remote('alice'), remote('bob'), local('self')], 'CONNECTED')
    expect(started).toHaveBeenCalledOnce()
    expect(started).toHaveBeenCalledWith('bob')

    alert.observe([remote('alice')], 'CONNECTED')
    alert.observe([remote('alice'), remote('bob')], 'CONNECTED')
    expect(started).toHaveBeenCalledTimes(2)
  })

  it('does not replay sound when publications disappear and return during reconnect', () => {
    const started = vi.fn()
    const alert = new StreamStartAlert(started)
    alert.observe([remote('alice')], 'CONNECTED')
    alert.observe([], 'RECONNECTING')
    alert.observe([], 'CONNECTED')
    alert.observe([remote('alice')], 'CONNECTED')
    alert.observe([remote('alice'), remote('bob')], 'CONNECTED')
    expect(started).toHaveBeenCalledOnce()
    expect(started).toHaveBeenCalledWith('bob')

    alert.observe([], 'IDLE')
    alert.observe([remote('bob')], 'CONNECTED')
    expect(started).toHaveBeenCalledOnce()
  })
})
