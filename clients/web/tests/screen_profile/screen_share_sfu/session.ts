import { LogLevel, Room, setLogLevel } from 'livekit-client'
import { SyntheticScreenPublisher } from './publisher'
import { ScreenShareViewer } from './viewer'

type Role = 'publisher' | 'viewer'

export class ScreenShareSfuSmoke {
  private room: Room | null = null
  private role: Role | null = null
  private readonly publisher = new SyntheticScreenPublisher()
  private readonly viewer = new ScreenShareViewer()

  async open(url: string, token: string, role: Role) {
    if (this.room) throw new Error('screen-share smoke client already connected')
    setLogLevel(LogLevel.silent)
    this.role = role
    const room = new Room({ adaptiveStream: false, dynacast: false })
    this.room = room
    if (role === 'viewer') this.viewer.bind(room)
    await room.connect(url, token, { autoSubscribe: role === 'publisher' })
  }

  async publishSynthetic() {
    if (!this.room || this.role !== 'publisher') throw new Error('publisher client required')
    await this.publisher.publish(this.room)
  }

  select() { this.requireViewer().select() }
  unselect() { this.requireViewer().unselect() }

  async snapshot() {
    const local = await this.publisher.snapshot()
    const remote = await this.viewer.snapshot()
    return { ...local, ...remote }
  }

  async stop() {
    const room = this.room
    this.room = null
    await this.publisher.stop(room)
    this.viewer.stop()
    await room?.disconnect(true)
    room?.removeAllListeners()
    this.role = null
  }

  private requireViewer() {
    if (this.role !== 'viewer') throw new Error('viewer client required')
    return this.viewer
  }
}
