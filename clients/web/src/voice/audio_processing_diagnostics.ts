import type { AudioProcessingOptions } from './media_publishing'

export type AudioProcessingReport = 'ENABLED' | 'DISABLED' | 'UNAVAILABLE'

export interface BrowserAudioProcessingSettings {
  autoGainControl?: boolean
  echoCancellation?: boolean
  noiseSuppression?: boolean
}

export interface AudioProcessingDiagnostic {
  reported: AudioProcessingReport
  requested: boolean
}

export interface AudioProcessingDiagnostics {
  autoGainControl: AudioProcessingDiagnostic
  echoCancellation: AudioProcessingDiagnostic
  noiseSuppression: AudioProcessingDiagnostic
}

function report(value: boolean | undefined): AudioProcessingReport {
  return value === undefined ? 'UNAVAILABLE' : value ? 'ENABLED' : 'DISABLED'
}

export function describeAudioProcessing(requested: AudioProcessingOptions, settings?: BrowserAudioProcessingSettings): AudioProcessingDiagnostics {
  return {
    autoGainControl: { requested: requested.autoGainControl, reported: report(settings?.autoGainControl) },
    echoCancellation: { requested: requested.echoCancellation, reported: report(settings?.echoCancellation) },
    noiseSuppression: { requested: requested.noiseSuppression, reported: report(settings?.noiseSuppression) },
  }
}

export function audioProcessingStatus(diagnostic: AudioProcessingDiagnostic): string {
  const requested = diagnostic.requested ? 'включено' : 'выключено'
  if (diagnostic.reported === 'UNAVAILABLE') return `Запрошено: ${requested}; браузер не сообщил состояние.`
  return `Запрошено: ${requested}; браузер сообщает: ${diagnostic.reported === 'ENABLED' ? 'включено' : 'выключено'}.`
}
