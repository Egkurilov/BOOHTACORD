import { describe,it,expect,vi } from 'vitest'
import { createGuildSettingsState } from './state'
import { GuildSettingsError } from './client'
const initial={name:'Первая',revision:1,welcomeChannelId:null}
describe('admin guild settings',()=>{
 it('preserves the draft on conflict, refreshes revision, requires explicit retry',async()=>{
  const read=vi.fn().mockResolvedValueOnce(initial).mockResolvedValueOnce({...initial,name:'Чужая',revision:2})
  const write=vi.fn().mockRejectedValueOnce(new GuildSettingsError(409)).mockResolvedValueOnce({...initial,name:'Моя',revision:3})
  const state=createGuildSettingsState(read,write);await state.load();state.name.value='Моя'
  await state.save([]);expect(state.name.value).toBe('Моя');expect(state.revision.value).toBe(2);expect(write).toHaveBeenCalledTimes(1)
  await state.save([]);expect(write.mock.calls[1][0].expected_revision).toBe(2)
 })
 it('rejects an unavailable welcome channel without sending a mutation',async()=>{
  const write=vi.fn();const state=createGuildSettingsState(async()=>initial,write);await state.load();state.welcome.value='gone'
  await state.save([]);expect(write).not.toHaveBeenCalled();expect(state.error.value).toContain('канал')
 })
 it('drops responses after dispose',async()=>{
  let done!:(value:typeof initial)=>void
  const state=createGuildSettingsState(()=>new Promise(resolve=>{done=resolve}),vi.fn());const pending=state.load();state.dispose();done(initial);await pending
  expect(state.revision.value).toBe(0)
 })
})
