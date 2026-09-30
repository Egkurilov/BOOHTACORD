import { readScreenShareDiagnostics, startScreenShare, stopScreenShare, type ScreenProfile, type VoiceRoom } from './livekit_gateway'
import { updateScreenShare } from './media_publishing'
import type { ScreenDiagnostics } from './screen_diagnostics'
import { tracedOperation } from '../telemetry/client_tracing'

export interface ScreenVoiceSession {
  room: VoiceRoom
  screenProfile: ScreenProfile | null
}

export class VoiceScreenSession {
  constructor(private readonly current: () => ScreenVoiceSession | null) {}

  async startScreen(profile: ScreenProfile): Promise<ScreenDiagnostics> {
    return tracedOperation('screen.share.start', async () => {
      const current = this.requireCurrent()
      const diagnostics = await startScreenShare(current.room, profile)
      current.screenProfile = profile
      return diagnostics
    })
  }

  async stopScreen(): Promise<void> {
    return tracedOperation('screen.share.stop', async () => {
      const current = this.current()
      if (!current || !current.screenProfile) return
      await stopScreenShare(current.room)
      current.screenProfile = null
    })
  }

  async updateScreenProfile(profile: ScreenProfile): Promise<ScreenDiagnostics> {
    const current = this.requireCurrent()
    if (!current.screenProfile) throw new Error('Демонстрация экрана не запущена.')
    const diagnostics = await updateScreenShare(current.room, profile)
    current.screenProfile = profile
    return diagnostics
  }

  async readScreenDiagnostics(): Promise<ScreenDiagnostics> {
    const current = this.current()
    if (!current || !current.screenProfile) throw new Error('Демонстрация экрана не запущена.')
    return readScreenShareDiagnostics(current.room)
  }

  private requireCurrent(): ScreenVoiceSession {
    const current = this.current()
    if (!current) throw new Error('Сначала подключитесь к голосовому каналу.')
    return current
  }
}
