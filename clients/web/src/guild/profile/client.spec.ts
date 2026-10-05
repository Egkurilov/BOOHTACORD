import { describe,it,expect,vi } from 'vitest'
import { loadGuildProfile } from './client'
describe('public one-guild profile',()=>{
 it('loads only name/revision without credentials or private settings',async()=>{
  const request=vi.fn().mockResolvedValue(new Response(JSON.stringify({name:'Гильдия 🙂',revision:2,welcome_channel_id:'private'})))
  expect(await loadGuildProfile(request)).toEqual({name:'Гильдия 🙂',revision:2})
  expect(request).toHaveBeenCalledWith(expect.stringMatching(/\/guild-profile$/),expect.objectContaining({method:'GET',credentials:'omit',cache:'no-store'}))
 })
 it.each([{name:'',revision:1},{name:'X',revision:0},{name:'X\nY',revision:2},{name:'🙂'.repeat(81),revision:1}])('rejects invalid public metadata %j',async body=>{
  await expect(loadGuildProfile(async()=>new Response(JSON.stringify(body)))).rejects.toThrow()
 })
})
