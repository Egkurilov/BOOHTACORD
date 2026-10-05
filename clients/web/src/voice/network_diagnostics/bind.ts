import { RoomEvent, type Room } from 'livekit-client'
import type { VoiceRoom } from '../livekit_gateway'
import { NetworkAttempt } from './attempt'
import { projectTransport } from './stats'
import { installNetworkReport } from './operator'
export function bindNetworkDiagnostics(room: VoiceRoom, liveKit: Room): void {
  const attempt = new NetworkAttempt()
  const original = room.connect.bind(room)
  let generation = 0
  let checking: ReturnType<typeof setInterval> | undefined
  const stop = () => { clearInterval(checking); checking = undefined }
  const inspectIce = () => {
    try {
      const manager = liveKit.engine.pcManager
      if ([manager?.publisher, manager?.subscriber].some(pc => ['connected', 'completed'].includes(pc?.getICEConnectionState() ?? ''))) attempt.ice()
    } catch { /* Optional diagnostics must never affect connection ownership. */ }
  }
  liveKit.on(RoomEvent.SignalConnected, () => attempt.signal())
  liveKit.on(RoomEvent.Disconnected, () => { generation++; stop(); attempt.disconnected() })
  liveKit.on(RoomEvent.Reconnecting, () => { generation++; stop(); attempt.start() })
  liveKit.on(RoomEvent.Reconnected, () => { inspectIce(); attempt.connected() })
  room.connect = async (...args) => {
    generation++; stop(); attempt.start()
    checking = setInterval(inspectIce, 250)
    try { await original(...args); inspectIce(); attempt.connected() }
    catch (error) { attempt.failed(); throw error }
    finally { stop() }
  }
  room.readNetworkDiagnostics = async () => {
    const epoch = generation
    const manager = liveKit.engine.pcManager
    const peers = [manager?.publisher, manager?.subscriber].filter(peer => peer !== undefined)
    const values = await Promise.all(peers.map(async peer => {
      let timer: ReturnType<typeof setTimeout> | undefined
      try {
        const report = await Promise.race([peer!.getStats(), new Promise<undefined>(resolve => { timer = setTimeout(() => resolve(undefined), 1500) })])
        return report ? projectTransport(report.values()) : null
      } catch { return null }
      finally { clearTimeout(timer) }
    }))
    if (epoch === generation) attempt.transports(values.filter(value => value !== null))
    return attempt.snapshot()
  }
  installNetworkReport(room.readNetworkDiagnostics)
}
