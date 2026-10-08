import type { ScreenDiagnostics } from '../../screen_diagnostics'
import type { ScreenProfile } from '../../screen_profile/policy'
import type { ScreenPublisherScope } from '../../screen_publisher/types'
import type { AdaptationCalibration, AdaptationWindow } from '../types'

export interface AdaptationInputContext { publicationGeneration: number; currentProfile: ScreenProfile; userCeiling: ScreenProfile }
export interface AdaptationRuntimeOptions {
  readonly enabled?: boolean
  readonly calibration?: AdaptationCalibration
  readonly now?: () => number
  readonly readWindow?: (diagnostics: ScreenDiagnostics, context: AdaptationInputContext) => AdaptationWindow | null | Promise<AdaptationWindow | null>
}
export interface AdaptationTicket<T> { scope: ScreenPublisherScope<T>; track: T; generation: number; revision: number; epoch: number }
export interface AdaptationApplyResult { reason: string; applied: boolean; revision?: number }
