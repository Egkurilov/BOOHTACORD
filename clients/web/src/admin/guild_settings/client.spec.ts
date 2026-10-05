import { describe,it,expect,vi } from 'vitest'
import { readGuildSettings,writeGuildSettings } from './client'
describe('admin guild settings transport',()=>{
 it('uses secure session transport and optimistic revision',async()=>{
  const request=vi.fn().mockImplementation(async()=>new Response(JSON.stringify({name:'Имя',revision:4,welcome_channel_id:null})))
  expect(await readGuildSettings(request)).toEqual({name:'Имя',revision:4,welcomeChannelId:null})
  await writeGuildSettings({name:'Имя',welcome_channel_id:null,expected_revision:3},request)
  expect(request.mock.calls[1][1]).toEqual(expect.objectContaining({method:'PATCH',credentials:'same-origin',cache:'no-store',body:JSON.stringify({name:'Имя',welcome_channel_id:null,expected_revision:3})}))
 })
})
