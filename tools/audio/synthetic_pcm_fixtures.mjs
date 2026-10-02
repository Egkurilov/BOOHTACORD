/** Original synthetic signals, CC0-1.0. No human recording or device data. */
export function syntheticPcm(sampleRate = 48000, seconds = 3) {
  const count = sampleRate * seconds, noise = new Float32Array(count), clean = new Float32Array(count), mixed = new Float32Array(count)
  let seed = 0x524e4e53
  for (let i = 0; i < count; i++) {
    seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5
    noise[i] = ((seed >>> 0) / 4294967296 * 2 - 1) * 0.06
    // Multi-frequency chirp; deliberately called a signal, not speech.
    const t = i / sampleRate
    clean[i] = t < 0.25 ? 0 : 0.14 * (Math.sin(2 * Math.PI * (120 * t + 55 * t * t)) + 0.4 * Math.sin(2 * Math.PI * 730 * t))
    mixed[i] = clean[i] + noise[i]
  }
  return { sampleRate, noise, clean, mixed }
}
export function rms(samples, start = 0) {
  let energy = 0
  for (let i = start; i < samples.length; i++) energy += samples[i] ** 2
  return Math.sqrt(energy / (samples.length - start))
}
