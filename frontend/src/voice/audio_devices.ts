export type AudioDeviceKind = 'audioinput' | 'audiooutput'

export interface AudioDevice {
  id: string
  label: string
}

export interface AudioDeviceCatalogue {
  getLocalDevices(kind: AudioDeviceKind, requestPermissions: false): Promise<MediaDeviceInfo[]>
}

export type AudioDeviceLoader = () => Promise<AudioDeviceCatalogue>

async function defaultCatalogue(): Promise<AudioDeviceCatalogue> {
  const { Room } = await import('livekit-client')
  return Room
}

function options(devices: MediaDeviceInfo[], kind: AudioDeviceKind): AudioDevice[] {
  return devices.map((device, index) => ({
    id: device.deviceId,
    label: device.label || (kind === 'audioinput' ? `Микрофон ${index + 1}` : `Динамик ${index + 1}`),
  }))
}

export async function listAudioDevices(load: AudioDeviceLoader = defaultCatalogue): Promise<{
  inputs: AudioDevice[]
  outputs: AudioDevice[]
}> {
  const catalogue = await load()
  const [inputs, outputs] = await Promise.all([
    catalogue.getLocalDevices('audioinput', false),
    catalogue.getLocalDevices('audiooutput', false),
  ])
  return { inputs: options(inputs, 'audioinput'), outputs: options(outputs, 'audiooutput') }
}
