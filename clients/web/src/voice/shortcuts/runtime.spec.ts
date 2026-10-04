import { afterEach, expect, it, vi } from 'vitest'
import { VoiceShortcuts } from '../voice_shortcuts'
import { executeVoiceShortcut } from './execute'
afterEach(() => vi.unstubAllGlobals())
it('serializes commands, checks focus and discards completion after stop', async () => {
 let listener: (e: KeyboardEvent) => void = () => undefined, focused = true
 vi.stubGlobal('document', { visibilityState: 'visible', hasFocus: () => focused })
 const source = { addEventListener: (_: 'keydown', next: typeof listener) => { listener = next }, removeEventListener: vi.fn() }
 let finish!: () => void
 const run = vi.fn(() => new Promise<void>(resolve => { finish = resolve })), announce = vi.fn()
 const binding = { code: 'KeyM', ctrlKey: true, altKey: false, shiftKey: false, metaKey: false }
 const manager = new VoiceShortcuts(source, () => ({ microphone: binding, deafen: null }), { microphone: run, deafen: vi.fn() }, announce)
 const event = { ...binding, preventDefault: vi.fn(), target: null } as unknown as KeyboardEvent
 manager.start(); focused = false; listener(event); expect(run).not.toHaveBeenCalled()
 focused = true; listener(event); listener(event); expect(run).toHaveBeenCalledOnce()
 manager.stop(); finish(); await Promise.resolve(); await Promise.resolve(); expect(announce).not.toHaveBeenCalled()
})
it('blocks unsafe microphone states and uses authoritative deafen operation', async () => {
 const voice = { active: { listenerOnly: false }, state: 'CONNECTED', deafenChanging: false, deafened: false, microphonePermissionDenied: false, microphoneMuted: true, toggleMicrophone: vi.fn(), toggleDeafen: vi.fn() }
 for (const state of ['JOINING', 'RECONNECTING', 'LEAVING']) { voice.state = state; expect(await executeVoiceShortcut('microphone', voice, 'VAD')).toBe('blocked') }
 voice.state = 'LISTENER'; voice.active.listenerOnly = true
 expect(await executeVoiceShortcut('microphone', voice, 'VAD')).toBe('blocked'); expect(voice.toggleMicrophone).not.toHaveBeenCalled()
 voice.state = 'CONNECTED'; voice.active.listenerOnly = false
 expect(await executeVoiceShortcut('microphone', voice, 'PTT')).toBe('blocked')
 voice.toggleDeafen.mockImplementation(async () => { voice.deafened = true })
 expect(await executeVoiceShortcut('deafen', voice, 'VAD')).toBe('applied'); expect(voice.toggleDeafen).toHaveBeenCalledOnce()
})

it('invalidates pending completion without allowing a second command while busy', async () => {
 vi.stubGlobal('document', { visibilityState:'visible',hasFocus:()=>true })
 let listener!: (event:KeyboardEvent)=>void,finish!:()=>void
 const source={ addEventListener: (_:'keydown',next:typeof listener)=>{listener=next},removeEventListener:vi.fn() }
 const binding={code:'KeyM',ctrlKey:true,altKey:false,shiftKey:false,metaKey:false},run=vi.fn(()=>new Promise<void>(resolve=>{finish=resolve})),announce=vi.fn()
 const manager=new VoiceShortcuts(source,()=>({microphone:binding,deafen:null}),{microphone:run,deafen:vi.fn()},announce)
 const event={...binding,target:null,preventDefault:vi.fn()} as unknown as KeyboardEvent
 manager.start(); listener(event); manager.invalidate(); listener(event); expect(run).toHaveBeenCalledOnce()
 finish(); await Promise.resolve(); await Promise.resolve(); expect(announce).not.toHaveBeenCalled(); manager.stop()
})
