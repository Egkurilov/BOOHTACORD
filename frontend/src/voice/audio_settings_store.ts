import { defineStore } from 'pinia'
import { ref } from 'vue'

import { listAudioDevices, type AudioDevice, type AudioDeviceKind } from './audio_devices'
import { createAudioProcessingControls, type AudioProcessingApplier } from './audio_processing_controls'
import type { AudioProcessingOptions } from './livekit_gateway'

export type AudioSettingsState = 'IDLE' | 'LOADING' | 'READY' | 'ERROR'
export type AudioDeviceSwitcher = (kind: AudioDeviceKind, deviceId: string) => Promise<void>
export type { AudioProcessingApplier } from './audio_processing_controls'

export const useAudioSettingsStore = defineStore('audio-settings', () => {
  const devices = ref<{ inputs: AudioDevice[]; outputs: AudioDevice[] }>({ inputs: [], outputs: [] })
  const error = ref<string | null>(null)
  const processingControls = createAudioProcessingControls()
  const processing = processingControls.processing
  const state = ref<AudioSettingsState>('IDLE')
  let scanSequence = 0

  async function load(scan: typeof listAudioDevices = listAudioDevices): Promise<void> {
    const sequence = ++scanSequence
    state.value = 'LOADING'
    error.value = null
    try {
      const found = await scan()
      if (sequence !== scanSequence) return
      devices.value = found
      state.value = 'READY'
    } catch {
      if (sequence !== scanSequence) return
      state.value = 'ERROR'
      error.value = 'Не удалось прочитать список аудиоустройств.'
    }
  }

  async function select(kind: AudioDeviceKind, deviceId: string, switchDevice: AudioDeviceSwitcher): Promise<void> {
    error.value = null
    try {
      await switchDevice(kind, deviceId)
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось переключить аудиоустройство.'
    }
  }

  async function loadProcessing(apply: AudioProcessingApplier): Promise<void> {
    error.value = null
    await processingControls.start(apply)
    error.value = processingControls.error.value
  }

  async function setProcessing(next: AudioProcessingOptions, apply: AudioProcessingApplier): Promise<void> {
    error.value = null
    await processingControls.set(next, apply)
    error.value = processingControls.error.value
  }

  return { devices, error, load, loadProcessing, processing, select, setProcessing, state }
})
