export interface MicrophoneCheck { level(): number; stop(): Promise<void> }

export function levelFromSamples(samples: Uint8Array): number {
  if (!samples.length) return 0
  let energy = 0
  for (const value of samples) energy += ((value - 128) / 128) ** 2
  return Math.min(100, Math.round(Math.sqrt(energy / samples.length) * 100))
}

export async function startMicrophoneCheck(
  deviceId: string,
  devices: Pick<MediaDevices, 'getUserMedia'> = navigator.mediaDevices,
  makeContext: () => AudioContext = () => new AudioContext(),
): Promise<MicrophoneCheck> {
  const stream = await devices.getUserMedia({ audio: deviceId && deviceId !== 'default'
    ? { deviceId: { exact: deviceId } } : true, video: false })
  let context: AudioContext
  try { context = makeContext() } catch (cause) { stream.getTracks().forEach((track) => track.stop()); throw cause }
  let source: MediaStreamAudioSourceNode
  let analyser: AnalyserNode
  try {
    source = context.createMediaStreamSource(stream)
    analyser = context.createAnalyser()
    analyser.fftSize = 256
    source.connect(analyser)
  } catch (cause) {
    stream.getTracks().forEach((track) => track.stop())
    await context.close()
    throw cause
  }
  const samples = new Uint8Array(analyser.fftSize)
  let stopped = false
  return {
    level: () => {
      if (stopped) return 0
      analyser.getByteTimeDomainData(samples)
      return levelFromSamples(samples)
    },
    stop: async () => {
      if (stopped) return
      stopped = true
      source.disconnect()
      stream.getTracks().forEach((track) => track.stop())
      await context.close()
    },
  }
}

export async function playSpeakerCheck(deviceId: string): Promise<void> {
  const context = new AudioContext()
  const destination = context.createMediaStreamDestination()
  const tone = context.createOscillator()
  const gain = context.createGain()
  const audio = new Audio()
  audio.srcObject = destination.stream
  tone.frequency.value = 440
  gain.gain.value = 0.12
  tone.connect(gain).connect(destination)
  let started = false
  try {
    if (deviceId && deviceId !== 'default') {
      if (!('setSinkId' in audio)) throw new Error('Этот браузер не умеет выбирать динамик для проверки звука.')
      await audio.setSinkId(deviceId)
    }
    await context.resume()
    tone.start()
    started = true
    await audio.play()
    await new Promise<void>((resolve) => setTimeout(resolve, 400))
  } finally {
    if (started) tone.stop()
    audio.pause()
    audio.srcObject = null
    await context.close()
  }
}
