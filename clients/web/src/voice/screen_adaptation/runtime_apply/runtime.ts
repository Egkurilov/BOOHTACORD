import type { ScreenPublisherAdapter } from '../../screen_publisher/adapter'
import { evaluateScreenAdaptation, initialScreenAdaptationState } from '../supervisor'
import { validatedCalibration } from '../profile_ladder'
import type { AdaptationState, AdaptationWindow } from '../types'
import type { AdaptationApplyResult, AdaptationRuntimeOptions, AdaptationTicket } from './types'

export class ScreenAdaptationRuntime<T> {
  state?: AdaptationState
  private previous?: AdaptationTicket<T>
  private epoch = 0
  readonly options: AdaptationRuntimeOptions
  constructor(readonly writer: ScreenPublisherAdapter<T>, options: AdaptationRuntimeOptions = {}) {
    this.options = Object.freeze({ ...options, calibration: options.calibration && structuredClone(options.calibration) })
  }
  get enabled(): boolean { return this.options.enabled === true && !!this.options.calibration && validatedCalibration(this.options.calibration) }
  reset(): void { ++this.epoch; this.state = undefined; this.previous = undefined }
  capture(): AdaptationTicket<T> | undefined {
    const active = this.writer.active, revision = this.writer.currentRevision
    if (!active || this.writer.busy || this.writer.stopping || !this.writer.valid(revision, active.scope) ||
      active.generation !== active.scope.port.generation() || active.scope.port.currentTrack() !== active.track) return undefined
    const ticket = { scope: active.scope, track: active.track, generation: active.generation, revision, epoch: this.epoch }
    const sameOwner = this.previous && this.sameOwner(this.previous, ticket)
    if (!sameOwner || this.previous?.revision !== revision || this.previous.generation !== ticket.generation) {
      const preserveCeiling = sameOwner && (this.previous?.revision === revision || this.writer.intent === 'repair')
      this.state = initialScreenAdaptationState(active.profile, preserveCeiling ? this.state?.ceilingProfile ?? active.profile : active.profile, active.generation)
    }
    this.previous = ticket
    return ticket
  }
  current(ticket: AdaptationTicket<T>): boolean {
    return this.matches(ticket, ticket.revision) && this.writer.active?.generation === ticket.generation &&
      ticket.scope.port.generation() === ticket.generation && !this.writer.busy
  }
  async step(window: AdaptationWindow, now: number, ticket: AdaptationTicket<T> | undefined = this.capture()): Promise<AdaptationApplyResult> {
    if (!this.enabled) return { reason: 'disabled-unvalidated', applied: false }
    if (!ticket || !this.current(ticket) || !this.state) return { reason: 'stale-owner', applied: false }
    const before = this.state, result = evaluateScreenAdaptation(before, window, now, this.options.calibration)
    if (result.decision.action !== 'change-profile' || !result.decision.profile) {
      this.state = result.state
      return { reason: result.decision.reason, applied: false }
    }
    const operation = this.writer.update(result.decision.profile), issued = this.writer.currentRevision
    try {
      await operation
      if (!this.matches(ticket, issued) || this.writer.active?.profile !== result.decision.profile) return { reason: 'superseded', applied: false }
      this.rebase(result.state, issued)
      return { reason: result.decision.reason, applied: true, revision: issued }
    } catch {
      if (this.matches(ticket, issued)) this.rebase(before, issued)
      return { reason: this.matches(ticket, issued) ? 'writer-failed' : 'superseded', applied: false }
    }
  }
  private rebase(state: AdaptationState, revision: number): void {
    const active = this.writer.active!
    this.state = { ...state, currentProfile: active.profile, publicationGeneration: active.generation }
    this.previous = { scope: active.scope, track: active.track, revision, generation: active.generation, epoch: this.epoch }
  }
  private matches(ticket: AdaptationTicket<T>, revision: number): boolean {
    const active = this.writer.active
    return ticket.epoch === this.epoch && revision === this.writer.currentRevision && this.writer.valid(revision, ticket.scope) && !!active &&
      this.sameOwner(ticket, { scope: active.scope, track: active.track }) && active.scope.port.currentTrack() === ticket.track &&
      active.generation === active.scope.port.generation() && !this.writer.stopping
  }
  private sameOwner(a: Pick<AdaptationTicket<T>, 'scope' | 'track'>, b: Pick<AdaptationTicket<T>, 'scope' | 'track'>): boolean {
    return a.scope.owner === b.scope.owner && a.scope.room === b.scope.room && a.scope.port === b.scope.port && a.track === b.track
  }
}
