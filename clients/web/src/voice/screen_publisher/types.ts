import type { ScreenDiagnostics } from '../screen_diagnostics'
import type { ScreenProfile } from '../screen_profile/policy'

export type ScreenPublisherOutcome = 'success' | 'cancel' | 'superseded' | 'failure'
export class ScreenPublisherOperationError extends Error {
  constructor(readonly outcome: Exclude<ScreenPublisherOutcome, 'success'>, message: string,
    readonly recovery?: 'restored' | 'cleanup-required', readonly operationCause?: unknown) {
    super(message); this.name = 'ScreenPublisherOperationError'
  }
}
export const emptyResolve = (..._args: never[]): void => {}
export interface ScreenPublisherPort<T> {
  generation(): number; isLive(track: T): boolean; currentTrack(): T | undefined
  start(profile: ScreenProfile): Promise<T | undefined>; capture(track: T, profile: ScreenProfile): Promise<void>
  unpublish(track: T, stopCapture: boolean): Promise<void>; publish(track: T, profile: ScreenProfile): Promise<void>
  repair?(track: T, profile: ScreenProfile, current: () => boolean): Promise<boolean>
  stop(track?: T): Promise<void>; diagnostics(): Promise<ScreenDiagnostics>
  adopt?(profile: ScreenProfile): void
  onEnded?(listener: () => void): () => void
  trackPublished?(): void; trackUnpublished?(track?: T): boolean | void
}
export interface ScreenPublisherScope<T> { owner: object; room: object; port: ScreenPublisherPort<T> }
export interface ActiveScreenPublication<T> { scope: ScreenPublisherScope<T>; track: T; profile: ScreenProfile; generation: number; repairAttempts: number }
export type ScreenPublishIntent<T> = {
  kind: 'start' | 'update' | 'repair'; revision: number; profile: ScreenProfile; scope: ScreenPublisherScope<T>
  resolve(value: ScreenDiagnostics): void; reject(error: unknown): void
}
