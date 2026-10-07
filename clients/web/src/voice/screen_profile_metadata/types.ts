export type ScreenProfileMode = 'motion' | 'text'
export type ScreenProfileId = 'P720_15' | 'P720_30' | 'P720_60' | 'P1080_15' | 'P1080_30' | 'P1080_60' | 'P1440_15' | 'P1440_30' | 'P1440_60'
export type ScreenPublisherState = 'idle' | 'requesting' | 'capturing' | 'publishing' | 'sharing' | 'updating' | 'stopping' | 'failed'
export type ScreenViewerState = 'idle' | 'subscribing' | 'waiting-first-frame' | 'playing' | 'suspended' | 'recovering' | 'ended' | 'failed'
export type ScreenReasonCode = 'user-request' | 'platform-constraint' | 'network-adaptation' | 'no-subscribers' | 'sdk-paused' | 'unsupported-profile' | 'capture-denied' | 'publish-failed' | 'superseded' | 'session-revoked' | 'logout' | 'unknown'

export interface ScreenDescriptorOwner { originId: string; accountId: string; roomId: string }
export interface ScreenDescriptorScope extends ScreenDescriptorOwner {
  mediaSessionId: string
  publicationGeneration: number
  operationRevision: number
}
export interface ScreenDescriptorLayer {
  rid: string | null
  width: number
  height: number
  max_fps: number
  max_bitrate_bps: number
  scale_down_by: number
  active: boolean
}
export interface ScreenShareDescriptorV1 {
  schema_version: 1
  scope: { origin_id: string; account_id: string; room_id: string; media_session_id: string; publication_generation: number; operation_revision: number }
  mode: ScreenProfileMode
  publisher_state: ScreenPublisherState
  viewer_state: ScreenViewerState
  requested_profile_id: ScreenProfileId
  effective_profile: {
    capture: { max_width: number; max_height: number; max_fps: number }
    encoding: { codec: string | null; layers: ScreenDescriptorLayer[] }
  }
  layer_topology: 'single-layer' | 'bounded-simulcast'
  profile_revision: number
  capabilities: { live_update: boolean; republish_without_recapture: boolean; simulcast: boolean }
  reason_codes: ScreenReasonCode[]
}
