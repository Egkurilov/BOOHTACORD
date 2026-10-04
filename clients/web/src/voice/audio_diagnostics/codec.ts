import { statNumber, type RawAudioStat } from './model'
const name = (value: unknown): string | null => {
  if (typeof value !== 'string') return null
  const codec = value.toLowerCase().replace('audio/', '')
  return ['opus', 'red', 'pcmu', 'pcma', 'g722', 'cn'].includes(codec) ? codec : 'other'
}
export function audioCodec(rtp: RawAudioStat, reports: RawAudioStat[]) {
  const transport = reports.find((entry) => entry.id === rtp.codecId && entry.type === 'codec')
  let decoded = transport
  const transportCodec = name(transport?.mimeType)
  if (transportCodec === 'red') {
    const payload = typeof transport?.sdpFmtpLine === 'string' ? Number(transport.sdpFmtpLine.split('/')[0]) : null
    decoded = reports.find((entry) => entry.type === 'codec' && statNumber(entry.payloadType) === payload && name(entry.mimeType) === 'opus')
  }
  const fmtp = typeof decoded?.sdpFmtpLine === 'string' ? decoded.sdpFmtpLine : ''
  const flag = (key: string): boolean | null => {
    const found = fmtp.split(';').map((part) => part.trim().split('=')).find(([name]) => name === key)
    return found?.[1] === '1' ? true : found?.[1] === '0' ? false : null
  }
  return { codec: name(decoded?.mimeType), transportCodec, codecChannels: statNumber(decoded?.channels),
    clockRate: statNumber(decoded?.clockRate), red: transportCodec === null ? null : transportCodec === 'red',
    dtx: flag('usedtx'), fec: flag('useinbandfec'), stereo: flag('stereo') }
}
