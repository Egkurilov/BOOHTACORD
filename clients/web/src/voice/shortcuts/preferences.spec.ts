import { afterEach, expect, it, vi } from 'vitest'
import { ref } from 'vue'
import { createShortcutSettings } from './state'
afterEach(() => vi.unstubAllGlobals())
it('isolates accounts, rejects restored conflicts and resets persistently', () => {
 const storage = new Map<string,string>(); vi.stubGlobal('localStorage', { getItem: (k:string) => storage.get(k) ?? null, setItem:(k:string,v:string) => storage.set(k,v) })
 const error = ref<string|null>(null), ptt = ref<string|null>(null), settings = createShortcutSettings(error, ptt)
 const binding = { code:'KeyM',ctrlKey:true,altKey:false,shiftKey:false,metaKey:false }
 settings.bindAccount('a'); expect(settings.setShortcut('microphone',binding)).toBe(true)
 settings.bindAccount('b'); expect(settings.microphoneShortcut.value).toBeNull()
 settings.bindAccount('a'); expect(settings.microphoneShortcut.value).toEqual(binding)
 settings.resetShortcuts(); settings.bindAccount('b'); settings.bindAccount('a'); expect(settings.microphoneShortcut.value).toBeNull()
 storage.set('voice-shortcuts:v1:b',JSON.stringify({microphone:binding,deafen:binding})); settings.bindAccount('b'); expect(settings.deafenShortcut.value).toBeNull()
 settings.unbindAccount(); expect(settings.microphoneShortcut.value).toBeNull()
})

it('rejects malformed stored bindings and leaves assignments unchanged on save failure', () => {
 const binding = { code:'KeyM',ctrlKey:true,altKey:false,shiftKey:false,metaKey:false }
 vi.stubGlobal('localStorage', { getItem: () => JSON.stringify({microphone:{...binding,ctrlKey:'yes'},deafen:{...binding,code:'KeyW'}}), setItem: () => { throw new Error('unavailable') } })
 const error=ref<string|null>(null),settings=createShortcutSettings(error,ref(null))
 settings.bindAccount('a'); expect(settings.microphoneShortcut.value).toBeNull(); expect(settings.deafenShortcut.value).toBeNull()
 expect(settings.setShortcut('microphone',binding)).toBe(false); expect(settings.microphoneShortcut.value).toBeNull(); expect(error.value).toContain('сохранить')
 settings.microphoneShortcut.value=binding; settings.resetShortcuts(); expect(settings.microphoneShortcut.value).toEqual(binding); expect(error.value).toContain('сбросить')
})
