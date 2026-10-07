import type { LocalVideoTrack } from 'livekit-client'
import { readScreenShareDiagnostics, type ScreenProfile, type VoiceRoom } from './livekit_gateway'
import type { ScreenDiagnostics } from './screen_diagnostics'
import { tracedOperation } from '../telemetry/client_tracing'
import { activeAction } from '../telemetry/action_scope/scope'
import { ScreenPublisherAdapter } from './screen_publisher/adapter'
import type { ScreenPublisherScope } from './screen_publisher/types'

export interface ScreenVoiceSession { room: VoiceRoom; screenProfile: ScreenProfile | null }

export class VoiceScreenSession {
  private stopEnded?: () => void
  private watchedRoom?: VoiceRoom
  private repairTimer?: ReturnType<typeof setTimeout>
  private repairGeneration = 0
  private readonly publisher = new ScreenPublisherAdapter<LocalVideoTrack>(() => this.scope())
  constructor(private readonly current: () => ScreenVoiceSession | null) {}

  async startScreen(profile: ScreenProfile): Promise<ScreenDiagnostics> {
    return tracedOperation('screen.share.start', async (within) => {
      const current = this.requireCurrent(); this.watch(current.room)
      activeAction()?.step('publish')
      const diagnostics = await within(() => this.publisher.start(profile))
      if (this.current() !== current) throw new Error('Голосовое подключение закрыто.')
      current.screenProfile = profile; this.scheduleRepairWatchdog(current, profile)
      await current.room.publishScreenProfileMetadata?.(profile).catch(() => undefined)
      return diagnostics
    })
  }
  async stopScreen(): Promise<void> {
    return tracedOperation('screen.share.stop', async () => {
      const current = this.current()
      this.cancelRepairWatchdog()
      try { await this.publisher.stop() } finally { await current?.room.clearScreenProfileMetadata?.().catch(() => undefined) }
      current?.room.stopScreenProfileChecks?.()
      if (current) current.screenProfile = null
    })
  }
  async updateScreenProfile(profile: ScreenProfile): Promise<ScreenDiagnostics> {
    const current = this.requireCurrent()
    if (!current.screenProfile) throw new Error('Демонстрация экрана не запущена.')
    const previous = current.screenProfile
    let diagnostics: ScreenDiagnostics
    try { diagnostics = await this.publisher.update(profile) }
    catch (cause) {
      if (this.current() === current && previous && this.publisher.active?.profile === previous) await current.room.publishScreenProfileMetadata?.(previous).catch(() => undefined)
      throw cause
    }
    if (this.current() !== current) throw new Error('Голосовое подключение закрыто.')
    current.room.adoptScreenProfile?.(profile); current.screenProfile = profile
    this.scheduleRepairWatchdog(current, profile)
    await current.room.publishScreenProfileMetadata?.(profile).catch(() => undefined)
    return diagnostics
  }
  async readScreenDiagnostics(): Promise<ScreenDiagnostics> {
    const current = this.current()
    if (!current || !current.screenProfile) throw new Error('Демонстрация экрана не запущена.')
    return readScreenShareDiagnostics(current.room)
  }
  cancel(): void {
    this.cancelRepairWatchdog()
    this.publisher.cancel()
    const current = this.current(); if (current) current.screenProfile = null
  }
  private watch(room: VoiceRoom): void {
    if (room === this.watchedRoom) return
    this.stopEnded?.(); this.watchedRoom = room
    this.stopEnded = room.screenPublisher?.onEnded?.(() => {
      const current = this.current()
      if (current?.room !== room || !current.screenProfile) return
      this.cancelRepairWatchdog(); current.screenProfile = null
      void room.clearScreenProfileMetadata?.().catch(() => undefined)
      void this.publisher.submitForEndedEvent().catch(() => {})
    })
  }
  private scheduleRepairWatchdog(session: ScreenVoiceSession, profile: ScreenProfile): void {
    this.cancelRepairWatchdog()
    const generation = this.repairGeneration
    this.repairTimer = setTimeout(() => { void this.inspectForRepair(session, profile, generation) }, 5000)
  }
  private cancelRepairWatchdog(): void {
    ++this.repairGeneration
    if (this.repairTimer) clearTimeout(this.repairTimer)
    this.repairTimer = undefined
  }
  private async inspectForRepair(session: ScreenVoiceSession, profile: ScreenProfile, generation: number): Promise<void> {
    if (!this.watchdogCurrent(session, profile, generation)) return
    try {
      const diagnostics = await readScreenShareDiagnostics(session.room)
      if (this.watchdogCurrent(session, profile, generation) && diagnostics.profileCheck?.status === 'drift') {
        await this.publisher.repairCurrent()
        await session.room.publishScreenProfileMetadata?.(profile).catch(() => undefined)
      }
    } catch { /* diagnostics and repair status remain available through the regular read path */ }
    if (this.watchdogCurrent(session, profile, generation)) this.repairTimer = setTimeout(() => { void this.inspectForRepair(session, profile, generation) }, 5000)
  }
  private watchdogCurrent(session: ScreenVoiceSession, profile: ScreenProfile, generation: number): boolean {
    return generation === this.repairGeneration && this.current() === session && session.screenProfile === profile && this.publisher.active?.profile === profile
  }
  private scope(): ScreenPublisherScope<LocalVideoTrack> | null {
    const current = this.current(), port = current?.room.screenPublisher
    return current && port ? { owner: current, room: current.room, port } : null
  }
  private requireCurrent(): ScreenVoiceSession {
    const current = this.current()
    if (!current) throw new Error('Сначала подключитесь к голосовому каналу.')
    return current
  }
}
