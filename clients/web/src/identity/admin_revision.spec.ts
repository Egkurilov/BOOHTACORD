import { expect,it,vi } from 'vitest'
import { AdminDirectoryError,updateAdminAccount } from './admin_directory_client'
it('sends exact server revision and exposes typed 409 without retry',async()=>{
  const request=vi.fn(async(_input:string,_init:RequestInit)=>new Response(JSON.stringify({error:{message:'conflict'}}),{status:409}))
  await expect(updateAdminAccount('a','MEMBER',false,request,'2026-10-05T12:00:00.123456Z')).rejects.toBeInstanceOf(AdminDirectoryError)
  expect(request).toHaveBeenCalledOnce()
  expect(JSON.parse(String(request.mock.calls[0][1]?.body))).toEqual({role:'MEMBER',blocked:false,expected_updated_at:'2026-10-05T12:00:00.123456Z'})
})
