import { describe, expect, it } from 'vitest'
import { SampleRingBuffer, toPcm16Float, fromPcm16Float } from './ring_buffer'
describe('bounded PCM FIFO', () => {
  it('wraps without reordering and refuses overflow', () => {
    const fifo = new SampleRingBuffer(3)
    expect(fifo.push(1)).toBe(true); fifo.push(2); fifo.push(3)
    expect(fifo.push(4)).toBe(false); expect(fifo.shift()).toBe(1)
    fifo.push(4); expect([fifo.shift(), fifo.shift(), fifo.shift()]).toEqual([2, 3, 4])
    expect(fifo.shift()).toBeUndefined()
  })
  it('zeros stored samples on reset', () => {
    const fifo = new SampleRingBuffer(480); fifo.push(0.5); fifo.clear()
    expect(fifo.size).toBe(0); expect(fifo.shift()).toBeUndefined()
  })
  it('scales exactly once, clips and sanitizes nonfinite PCM', () => {
    expect(toPcm16Float(0.5)).toBe(16384)
    expect(fromPcm16Float(16384)).toBe(0.5)
    expect([-2, 2, NaN, Infinity, -Infinity].map(toPcm16Float)).toEqual([-32768, 32768, 0, 0, 0])
    expect(fromPcm16Float(100000)).toBe(1); expect(fromPcm16Float(NaN)).toBe(0)
  })
})
