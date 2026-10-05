import { expect, it, vi } from 'vitest'
import { bindNetworkDiagnostics } from './bind'
it('keeps connect arguments and original rejection and bounds stats collection', async () => {
  const error = new Error('private-token-in-sdk-error')
  const callbacks: Record<string, () => void> = {}
  const connect = vi.fn(async () => { callbacks.signalConnected?.(); throw error })
  const room: any = { connect, on: (name: string, fn: () => void) => { callbacks[name] = fn }, engine: {} }
  bindNetworkDiagnostics(room, room)
  await expect(room.connect('private-url', 'secret-token', { autoSubscribe: false })).rejects.toBe(error)
  callbacks.disconnected?.()
  expect(connect).toHaveBeenCalledWith('private-url', 'secret-token', { autoSubscribe: false })
  expect(await room.readNetworkDiagnostics()).toMatchObject({ outcome: 'failed', transports: [] })
  expect(JSON.stringify(await room.readNetworkDiagnostics())).not.toMatch(/private-url|private-token|secret-token/)
})
it('ignores stale stats after the room disconnects', async () => {
  const callbacks: Record<string, () => void> = {}
  let finish!: (report: Map<string, any>) => void
  const room: any = { connect: async () => {}, on: (name: string, fn: () => void) => { callbacks[name] = fn },
    engine: { pcManager: { publisher: { getStats: () => new Promise(resolve => { finish = resolve }), getICEConnectionState: () => 'connected' } } } }
  bindNetworkDiagnostics(room, room); await room.connect('url', 'token')
  const report = room.readNetworkDiagnostics()
  callbacks.disconnected?.(); finish(new Map([['x', { type: 'outbound-rtp', kind: 'audio', bytesSent: 99 }]]))
  expect((await report).transports).toEqual([])
})
