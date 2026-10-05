import { afterEach,expect,it,vi } from 'vitest'
import { createDiagnosisSeries } from './series'
afterEach(()=>vi.useRealTimers())
it('collects only for an explicit bounded one-minute run and disposes without residual callbacks',()=>{
  vi.useFakeTimers();let now=0;const read=vi.fn(()=>({state:'playing',rttMs:null}))
  const series=createDiagnosisSeries(read,()=>now);expect(read).not.toHaveBeenCalled()
  series.begin()
  for(let index=0;index<35;index++){now+=2000;vi.advanceTimersByTime(2000)}
  expect(series.samples.value).toHaveLength(30);expect(series.collecting.value).toBe(false)
  series.clear();vi.advanceTimersByTime(2000);expect(series.samples.value).toHaveLength(0)
})
