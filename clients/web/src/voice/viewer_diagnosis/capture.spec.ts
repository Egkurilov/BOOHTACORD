import { expect,it } from 'vitest'
import { readSourceCounters } from './capture'
it('reads capture and encoding counters from linked native stats without exporting report identifiers',async()=>{
  const reports=new Map([['out',{id:'private-track',type:'outbound-rtp',kind:'video',frameWidth:1920,frameHeight:1080,framesEncoded:44,mediaSourceId:'source'}],['source',{type:'media-source',kind:'video',frames:70,trackIdentifier:'secret',ip:'127.0.0.1'}]])
  const value=await readSourceCounters({getStats:async()=>reports as unknown as RTCStatsReport})
  expect(value).toEqual({capturedFrames:70,encodedFrames:44});expect(JSON.stringify(value)).not.toContain('secret')
})
it('leaves absent or invalid capture and encoding counters unknown',async()=>{
  expect(await readSourceCounters(undefined)).toEqual({capturedFrames:null,encodedFrames:null})
  expect(await readSourceCounters({getStats:async()=>{throw new Error('unavailable')}})).toEqual({capturedFrames:null,encodedFrames:null})
})
