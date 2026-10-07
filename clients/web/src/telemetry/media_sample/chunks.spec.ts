import { expect, it } from 'vitest'
import { mediaSampleChunks } from './chunks'
it('splits wide samples while retaining provenance and room for trusted relay identity', () => {
 const core = Object.fromEntries(Array.from({length:11},(_,i)=>['core'+i,i]))
 const measurement = Object.fromEntries(Array.from({length:25},(_,i)=>['measurement'+i,i]))
 const sampled = {...measurement,'app.media.direction':'receiver','app.media.sample_state':'fresh','app.media.source':'webrtc',
  'app.sample.age_ms':0,'app.media.stats_window_ms':1000,'app.media.stats_source':'webrtc_interval',
  'app.media.presentation_source':'web_rvfc','app.media.collection_state':'active'}
 const chunks=mediaSampleChunks(core,sampled)
 expect(chunks).toHaveLength(3)
 for(const chunk of chunks){expect(Object.keys(chunk).length).toBeLessThanOrEqual(31);expect(chunk['app.media.stats_source']).toBe('webrtc_interval')}
 expect(Object.assign({},...chunks)).toMatchObject(measurement)
})
