import { describe, expect, it, vi } from 'vitest'
import { AudioInputPreferences } from './audio_input_preferences'
import { createAudioInputControls } from './audio_input_controls'

function fixture() {
  const values = new Map<string, string>()
  const preferences = new AudioInputPreferences({ getItem: key => values.get(key) ?? null, setItem: (key, value) => { values.set(key, value) } })
  let accountId = 'account-a'
  const controls = createAudioInputControls(async () => ({ accountId }), preferences)
  const apply = vi.fn(async (deviceId: string) => ({ deviceId, outcome: 'success' as const }))
  return { preferences, controls, apply, account: (id: string) => { accountId = id }, values }
}

describe('account microphone selection', () => {
  it('saves a prejoin selection and restores it for the same account without a probe', async () => {
    const f = fixture()
    await f.controls.start(f.apply)
    await f.controls.select('mic-2', f.apply)
    expect(f.preferences.get()).toBe('mic-2')
    const reopened = createAudioInputControls(async () => ({ accountId: 'account-a' }), f.preferences)
    await reopened.start(f.apply)
    expect(f.apply).toHaveBeenLastCalledWith('mic-2')
    expect(reopened.selectedInput.value).toBe('mic-2')
  })
  it('isolates account preferences and discards an old pending switch result', async () => {
    const f = fixture()
    await f.controls.start(f.apply)
    let finish!: (result: { deviceId: string; outcome: 'success' }) => void
    const old = f.controls.select('mic-2', () => new Promise(resolve => { finish = resolve }))
    await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
    f.account('account-b')
    const fresh = f.controls.start(f.apply)
    finish({ deviceId: 'mic-2', outcome: 'success' })
    await Promise.all([old, fresh])
    expect(f.controls.selectedInput.value).toBe('default')
    expect(f.preferences.get()).toBe('default')
    f.preferences.bind('account-a')
    expect(f.preferences.get()).toBe('default')
  })
  it('commits the confirmed fallback and shows its warning', async () => {
    const f = fixture()
    await f.controls.start(f.apply)
    await f.controls.select('missing', async () => ({ deviceId: 'default', outcome: 'fallback', warning: 'Микрофон отключён.' }))
    expect(f.controls.selectedInput.value).toBe('default')
    expect(f.preferences.get()).toBe('default')
    expect(f.controls.warning.value).toBe('Микрофон отключён.')
  })
  it('keeps the previous confirmed selection when switching rejects', async () => {
    const f = fixture()
    await f.controls.start(f.apply)
    await f.controls.select('mic-1', f.apply)
    await f.controls.select('mic-2', async () => { throw new Error('device details must not be exposed') })
    expect(f.controls.selectedInput.value).toBe('mic-1')
    expect(f.preferences.get()).toBe('mic-1')
    expect(f.controls.warning.value).toBe('Не удалось переключить микрофон. Сохранён предыдущий выбор.')
  })
  it('serializes rapid choices and persists only confirmed results', async () => {
    const f = fixture()
    await f.controls.start(f.apply)
    let finish!: () => void
    const one = f.controls.select('mic-1', async deviceId => { await new Promise<void>(resolve => { finish = resolve }); return { deviceId, outcome: 'success' } })
    await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
    const two = f.controls.select('mic-2', f.apply)
    expect(f.preferences.get()).toBe('default')
    finish()
    await Promise.all([one, two])
    expect(f.preferences.get()).toBe('mic-2')
  })
  it('warns when storage is blocked but retains the choice for this session', async () => {
    const preferences = new AudioInputPreferences({ getItem: () => null, setItem: () => { throw new Error('blocked') } })
    const controls = createAudioInputControls(async () => ({ accountId: 'account-a' }), preferences)
    const apply = async (deviceId: string) => ({ deviceId, outcome: 'success' as const })
    await controls.start(apply)
    await controls.select('mic-2', apply)
    expect(controls.selectedInput.value).toBe('mic-2')
    expect(preferences.get()).toBe('mic-2')
    expect(controls.warning.value).toContain('не удалось сохранить')
  })
})
