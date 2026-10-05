import { statNumber, type AudioDirection, type RawAudioStat } from './model'
export function audioInterval(current: RawAudioStat, previous: RawAudioStat | undefined,
  at: number, previousAt: number | undefined, direction: AudioDirection) {
  const dt = previousAt === undefined ? 0 : at - previousAt
  const changed = previous !== undefined && ['ssrc', 'codecId', 'mediaSourceId', 'mid', 'transportId']
    .some((key) => current[key] !== previous[key])
  const timestamp = statNumber(current.timestamp), oldTimestamp = statNumber(previous?.timestamp)
  const fresh = !previous || changed || timestamp === null || oldTimestamp === null || timestamp > oldTimestamp
  const suffix = direction === 'sender' ? 'Sent' : 'Received'
  const reset = [`bytes${suffix}`, `packets${suffix}`].some((key) => {
    const now = statNumber(current[key]), old = statNumber(previous?.[key])
    return now !== null && old !== null && now < old
  })
  return { fresh, valid: fresh && !changed && !reset && Number.isFinite(dt) && dt > 0 && dt <= 15000 }
}
