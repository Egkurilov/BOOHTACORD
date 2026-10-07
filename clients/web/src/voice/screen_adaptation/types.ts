import type { ScreenProfile } from '../screen_profile/policy'

export type AdaptationContent = 'motion' | 'text'
export type SharedBottleneck = 'source-limited' | 'encoder-cpu-thermal' | 'publisher-uplink'
export type ScreenBottleneck = SharedBottleneck | 'receiver-downlink-decode' | 'rendering' | 'unknown'
export type SignalProvenance = 'capture' | 'sender-encoder' | 'publisher-network' | 'receiver-network' | 'renderer'

export interface AdaptationSignal {
  provenance: SignalProvenance
  bottleneck: ScreenBottleneck
  condition: 'pressure' | 'clear'
  observedAtMs: number
  publicationGeneration: number
  receiverId?: string
}

export interface AdaptationWindow {
  id: string
  observedAtMs: number
  publicationGeneration: number
  content: AdaptationContent
  source: 'moving' | 'static' | 'unknown'
  visible: boolean
  warmedUp: boolean
  publication: 'sharing' | 'paused' | 'stopped'
  subscribers: number | null
  signals: readonly AdaptationSignal[]
}

export interface AdaptationCalibration {
  evidence: { status: 'PASS' | 'NOT_RUN' | 'BLOCKED'; sha: string }
  maxSignalAgeMs: number
  maximumWindowGapMs: number
  minIndependentSources: number
  pressureWindows: number
  recoveryDurationMs: number
  minimumDwellMs: number
  maxTransitionsPerGeneration: number
  ladders: Record<SharedBottleneck, Record<AdaptationContent, readonly ScreenProfile[]>>
}

export interface AdaptationState {
  currentProfile: ScreenProfile
  ceilingProfile: ScreenProfile
  publicationGeneration: number
  pressureBottleneck?: SharedBottleneck
  pressureWindows: number
  healthySinceMs?: number
  lastTransitionAtMs?: number
  lastWindowId?: string
  lastWindowAtMs?: number
  trendContent?: AdaptationContent
  transitions: number
}

export interface AdaptationDecision {
  action: 'hold' | 'change-profile'
  reason: string
  profile?: ScreenProfile
  bottleneck?: SharedBottleneck
  priority?: 'voice-first'
}

export interface AdaptationResult { state: AdaptationState; decision: AdaptationDecision }
