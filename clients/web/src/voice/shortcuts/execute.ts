import type { VoiceShortcutAction } from './model'
export interface ShortcutVoice {
 active: { listenerOnly?: boolean } | null
 state: string
 deafenChanging: boolean
 deafened: boolean
 microphonePermissionDenied: boolean
 microphoneMuted: boolean
 toggleMicrophone(): Promise<void>
 toggleDeafen(): Promise<void>
}
export async function executeVoiceShortcut(action: VoiceShortcutAction, voice: ShortcutVoice, mode: string): Promise<'applied' | 'blocked'> {
 if (!voice.active || !['CONNECTED', 'LISTENER'].includes(voice.state) || voice.deafenChanging) return 'blocked'
 if (action === 'microphone' && (mode === 'PTT' || voice.deafened || voice.microphonePermissionDenied || voice.active.listenerOnly || voice.state === 'LISTENER')) return 'blocked'
 const room = voice.active
 const previous = action === 'microphone' ? voice.microphoneMuted : voice.deafened
 if (action === 'microphone') await voice.toggleMicrophone()
 else await voice.toggleDeafen()
 return voice.active === room && previous !== (action === 'microphone' ? voice.microphoneMuted : voice.deafened) ? 'applied' : 'blocked'
}
