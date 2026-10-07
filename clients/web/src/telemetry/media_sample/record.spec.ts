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


it('retains bounded interval fields without any diagnostic IDs or content', () => {
 const attrs=sampleAttributes({sample_age_ms:0,direction:'sender',total_bitrate_kbps:1200,selected_layer_bitrate_kbps:800,
  encode_ms_per_frame:2,stats_source:'webrtc_interval',stats_window_ms:1000,rid:'f',ssrc:99,body:'private'})
 expect(attrs).toMatchObject({'app.media.total_bitrate_kbps':1200,'app.media.selected_layer_bitrate_kbps':800,'app.media.stats_window_ms':1000,'app.media.stats_source':'webrtc_interval'})
 expect(JSON.stringify(attrs)).not.toContain('private')
 expect(JSON.stringify(attrs)).not.toContain('ssrc')
})
