import type { ScreenReceiverMetrics } from '../screen_receiver_diagnostics'

export type WebPlatform = 'ios_web' | 'android_web' | 'desktop_web'
export interface ScreenMeasurementFields {
  total_bitrate_kbps?: number
  selected_layer_bitrate_kbps?: number
  retransmitted_bitrate_kbps?: number
  encode_ms_per_frame?: number
  decode_ms_per_frame?: number
  jitter_buffer_ms_per_frame?: number
  nack_per_second?: number
  pli_per_second?: number
  fir_per_second?: number
  first_frame_ms?: number
  freeze_duration_ms?: number
  freeze_count?: number
  stats_window_ms?: number
  stats_source?: 'webrtc_interval' | 'unsupported'
  presentation_source?: 'web_rvfc' | 'unsupported'
  collection_state?: 'active' | 'inactive' | 'sdk_paused' | 'hidden' | 'reconnecting' | 'unavailable' | 'stale' | 'unknown' | 'no_subscriber'
}
export interface ScreenClientReport extends ScreenMeasurementFields {
  profile_check_status?: import('../screen_profile/types').ProfileStatus
  profile_check_reason?: import('../screen_profile/types').ProfileReason
  profile_repair_attempts?: number
  capture_width?: number
  capture_height?: number
  capture_fps?: number
  platform: WebPlatform
  direction: 'sender' | 'receiver' | 'connection'
  state: 'waiting_subscription' | 'waiting_first_frame' | 'playing' | 'stalled'
  frame_width?: number
  frame_height?: number
  presented_fps?: number
  encoded_fps?: number
  decoded_fps?: number
  bitrate_kbps?: number
  jitter_ms?: number
  packets_lost?: number
  dropped_frames?: number
  rtt_ms?: number
  packet_loss_percent?: number
  packet_loss_window_ms?: number
  target_resolution?: number
  target_fps?: number
  sample_age_ms?: number
  connection_quality?: string
  adaptation_reason?: string
}
export interface ScreenClientReportInput {
  platform: WebPlatform
  selected: boolean
  hasTrack: boolean
  videoReady: boolean
  playbackFps: number | null
  receiverMetrics: ScreenReceiverMetrics | null
  sampledAt?: number
  firstFrameMs?: number | null
  presentationSource?: ScreenMeasurementFields['presentation_source']
  packetLossWindowMs?: number
  frameWidth?: number
  frameHeight?: number
}
