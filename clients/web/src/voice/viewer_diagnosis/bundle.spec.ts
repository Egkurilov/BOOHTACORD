import { expect,it } from 'vitest'
import { buildBundle,parseBundle,sanitizeSample } from './bundle'
it('exports only whitelisted bounded measurements; unknown RTT remains null',()=>{
  const input={elapsedMs:2000,state:'playing',captureFps:60,encodedFps:30,decodedFps:20,presentedFps:15,rttMs:null,token:'secret',SDP:'private',accountId:'user',roomId:'room',trackId:'track',IP:'127.0.0.1'}
  const sample=sanitizeSample(input),bundle=buildBundle([sample]),serialized=JSON.stringify(bundle)
  for(const forbidden of ['secret','SDP','accountId','roomId','trackId','127.0.0.1']) expect(serialized).not.toContain(forbidden)
  expect(bundle.receivers[0].samples[0].rttMs).toBeNull();expect(bundle.receivers[0].samples[0].presentedFps).toBe(15)
  expect(parseBundle(serialized)).toEqual(bundle)
})
it('supports exactly two receiver slots and rejects unbounded or invalid imported evidence',()=>{
  const sample=sanitizeSample({elapsedMs:0,state:'playing',encodedFps:Infinity})
  const paired=buildBundle([sample],[sample]);expect(paired.receivers.map(r=>r.slot)).toEqual([1,2])
  expect(sample.encodedFps).toBeNull()
  expect(()=>parseBundle(JSON.stringify({schema:paired.schema,receivers:[{slot:1,samples:Array(31).fill(sample)}]}))).toThrow()
  expect(()=>parseBundle('x'.repeat(32769))).toThrow()
})
