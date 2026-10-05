import { expect,it } from 'vitest'
import { diagnose } from './model'
const base={selected:true,ended:false,visible:true,local:false,hasAudio:true,videoReady:true,presentedFps:30,sampledAt:10000,selectedAt:0,now:11000}
it('distinguishes no first frame, frozen video, absent audio and stale observations',()=>{
  expect(diagnose({...base,videoReady:false}).state).toBe('no_first_frame')
  expect(diagnose({...base,presentedFps:0}).state).toBe('frozen')
  expect(diagnose({...base,hasAudio:false}).state).toBe('no_audio')
  expect(diagnose({...base,sampledAt:0}).state).toBe('stale_metrics')
  expect(diagnose({...base,sampledAt:null}).state).toBe('stale_metrics')
})
it('does not claim playback failure in a hidden tab or before the initial grace interval',()=>{
  expect(diagnose({...base,visible:false,presentedFps:0}).state).toBe('background')
  expect(diagnose({...base,videoReady:false,selectedAt:10000}).state).toBe('connecting')
  expect(diagnose({...base,presentedFps:null}).state).toBe('playing')
})
