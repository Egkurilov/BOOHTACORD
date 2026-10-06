import {expect,it} from 'vitest'
import {sampleAttributes} from './record'
it('does not turn absent or stale measurements into fresh zeros',()=>{
 expect(sampleAttributes({direction:'receiver',decoded_fps:20})).toEqual({
  'app.media.sample_state':'unknown','app.media.direction':'receiver','app.media.source':'webrtc'})
 expect(sampleAttributes({sample_age_ms:16000,decoded_fps:20})).not.toHaveProperty('app.media.decoded_fps')
 expect(sampleAttributes({sample_age_ms:NaN,decoded_fps:20})).not.toHaveProperty('app.media.decoded_fps')
 expect(sampleAttributes({sample_age_ms:0,capture_fps:30})).not.toHaveProperty('app.media.capture_fps')
 expect(sampleAttributes({sample_age_ms:0,decoded_fps:0,bitrate_kbps:NaN,body:'private'})).toMatchObject({'app.media.decoded_fps':0})
 expect(JSON.stringify(sampleAttributes({sample_age_ms:0,body:'private',rtt_ms:Infinity}))).not.toContain('private')
})
