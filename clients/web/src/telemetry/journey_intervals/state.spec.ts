import { afterEach,expect,it,vi } from 'vitest'
import { createJourneyRecorder } from './state'
afterEach(()=>vi.useRealTimers())
it('is inert until an explicit synthetic run, records real monotonic durations and drops late generations',()=>{
  vi.useFakeTimers();let now=0;const recorder=createJourneyRecorder(()=>now)
  const disabled=recorder.begin('send_ack');now=5;disabled('completed');expect(recorder.rows.value).toEqual([])
  recorder.start();const first=recorder.begin('send_ack');now=12;first('completed');first('completed')
  expect(recorder.rows.value).toEqual([{kind:'send_ack',durationMs:7,outcome:'completed'}])
  const late=recorder.begin('voice_connect');recorder.stop();late('completed');expect(recorder.rows.value).toHaveLength(1)
})
it('bounds pending work and output, and cancels after five minutes without invented zero observations',()=>{
  vi.useFakeTimers();let now=0;const recorder=createJourneyRecorder(()=>now);recorder.start()
  for(let index=0;index<60;index++){const finish=recorder.begin('select_first_frame');now+=5;finish('completed')}
  expect(recorder.rows.value).toHaveLength(50);expect(recorder.rows.value.every(r=>r.durationMs>0)).toBe(true)
  vi.advanceTimersByTime(300000);expect(recorder.active.value).toBe(false)
})
