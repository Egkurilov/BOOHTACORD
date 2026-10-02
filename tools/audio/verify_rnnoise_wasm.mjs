/** Deterministic scalar WASM sanity gate. No recordings or acoustic claims. */
import { readFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { resolve } from 'node:path'
const directory = resolve('clients/web/public/audio/rnnoise/v0.1-cdf196b')
const info = JSON.parse(readFileSync(resolve(directory, 'rnnoise-manifest.json')))
const bytes = readFileSync(resolve(directory, 'rnnoise.wasm'))
if (createHash('sha256').update(bytes).digest('hex') !== info.wasmSha256) throw new Error('WASM digest mismatch')
const module = new WebAssembly.Module(bytes)
if (WebAssembly.Module.imports(module).length) throw new Error('Unexpected WASM imports')
const dsp = new WebAssembly.Instance(module, {}).exports
dsp._initialize()
if (dsp.ns_init() !== 1) throw new Error('State init failed')
const input = new Float32Array(dsp.memory.buffer, dsp.ns_input(), 480)
const output = new Float32Array(dsp.memory.buffer, dsp.ns_output(), 480)
for (let i = 0; i < 100; i++) { input.fill(0); dsp.ns_process(); if (!output.every(value => Number.isFinite(value) && Math.abs(value) < 0.0001)) throw new Error('Silence failed') }
function signal() {
  const samples = new Float32Array(480 * 20)
  for (let frame = 0; frame < 20; frame++) {
    for (let i = 0; i < 480; i++) input[i] = 5000 * Math.sin((frame * 480 + i) * 2 * Math.PI * 440 / 48000)
    dsp.ns_process(); samples.set(output, frame * 480)
  }
  if (!samples.every(Number.isFinite)) throw new Error('Nonfinite PCM output')
  return samples
}
dsp.ns_reset(); const first = signal(); dsp.ns_reset(); const second = signal()
if (!first.every((value, index) => value === second[index])) throw new Error('Model reset is nondeterministic')
console.log(JSON.stringify({ status: 'PASS', wasmSha256: info.wasmSha256, modelSha256: info.modelSha256, frames: 140, imports: 0, reset: 'deterministic', acousticQuality: 'NOT_RUN' }))
