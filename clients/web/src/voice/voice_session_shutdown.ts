import type { ActiveVoiceSession, VoiceAdmission } from './voice_session_types'
import type { VoiceReconnectMonitor } from './voice_reconnect_monitor'
import type { VoiceDeafen } from './voice_deafen'
import type { VoiceScreenSession } from './voice_screen_session'
import { tracedOperation } from '../telemetry/client_tracing'
import { telemetrySession } from '../telemetry/action_scope/session'

interface VoiceSessionShutdownState {
  current(): ActiveVoiceSession | null
  setCurrent(value: ActiveVoiceSession | null): void
  admission: VoiceAdmission
  monitor: VoiceReconnectMonitor
  screen: VoiceScreenSession
  deafen: VoiceDeafen
  stopInputSelection(): (() => void) | undefined
  setStopInputSelection(value?: () => void): void
}

export class VoiceSessionShutdown {
  constructor(private readonly state: VoiceSessionShutdownState) {}

  leave(): Promise<void> {
    return tracedOperation('voice.leave', async (within) => {
      const current = this.state.current()
      if (!current) return
      await this.state.monitor.whileLeaving(async () => {
        this.state.screen.cancel()
        await current.room.disconnect()
        this.state.stopInputSelection()?.()
        this.state.setStopInputSelection(undefined)
        this.state.setCurrent(null)
        telemetrySession.endMedia()
        this.state.deafen.reset()
        await within(() => this.state.admission.release(current.leaseId))
      })
    })
  }

  async revoke(leaseId: string): Promise<boolean> {
    const current = this.state.current()
    if (!current || current.leaseId !== leaseId) return false
    await this.state.monitor.whileLeaving(async () => {
      this.state.screen.cancel()
      await current.room.disconnect()
      this.state.stopInputSelection()?.()
      this.state.setStopInputSelection(undefined)
      this.state.setCurrent(null)
      telemetrySession.endMedia()
      this.state.deafen.reset()
    })
    return true
  }
}
