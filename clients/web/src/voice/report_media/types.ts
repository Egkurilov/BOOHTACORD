import type { ScreenReceiverMetrics } from '../screen_receiver_diagnostics'

export type WebPlatform = 'ios_web' | 'android_web' | 'desktop_web'
export interface ScreenClientReport {
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
  packetLossWindowMs?: number
  frameWidth?: number
  frameHeight?: number
}
