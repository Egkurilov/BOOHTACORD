export interface AudioInputSelection {
  deviceId: string
  outcome: 'success' | 'fallback' | 'error'
  warning?: string
}
export type AudioInputApplier = (deviceId: string) => Promise<AudioInputSelection>
export type AudioInputPhase = 'prejoin' | 'active' | 'reconnect'

export function inputConstraints(deviceId: string): Pick<MediaTrackConstraints, 'deviceId'> {
  return deviceId && deviceId !== 'default' ? { deviceId: { exact: deviceId } } : {}
}

export function missingAudioInput(cause: unknown): boolean {
  const name = (cause as { name?: string } | null)?.name
  return name === 'NotFoundError' || name === 'OverconstrainedError'
}
