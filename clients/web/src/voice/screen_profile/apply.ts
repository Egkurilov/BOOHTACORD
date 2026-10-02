import { profileDimensions, profileScale, screenProfile, type ScreenProfile } from './policy'
import { abortProfile, sameBinding, trackBinding, type ProfileTrack } from './types'

export async function applyScreenProfile(track: ProfileTrack, profile: ScreenProfile, current: () => boolean = () => true): Promise<void> {
  const binding = trackBinding(track), target = screenProfile(profile)
  const valid = () => current() && sameBinding(track, binding)
  if (!valid()) throw abortProfile()
  if (!binding.sender) throw new Error('Активный видеоэнкодер демонстрации недоступен.')
  const dimensions = profileDimensions(profile, binding.capture.getSettings())
  await binding.capture.applyConstraints({ width: { max: dimensions.width }, height: { max: dimensions.height }, frameRate: { max: target.frameRate } })
  if (!valid()) throw abortProfile()
  const parameters = binding.sender.getParameters()
  if (!parameters.encodings?.length) throw new Error('Видеоэнкодер не предоставил параметры качества.')
  const scale = profileScale(profile, binding.capture.getSettings())
  const base = Math.min(...parameters.encodings.map(e => e.scaleResolutionDownBy ?? 1))
  for (const encoding of parameters.encodings) {
    const relative = (encoding.scaleResolutionDownBy ?? 1) / base
    encoding.scaleResolutionDownBy = scale * relative
    encoding.maxBitrate = Math.max(200_000, Math.round(target.bitrate / (relative * relative)))
    encoding.maxFramerate = target.frameRate
  }
  if (!valid()) throw abortProfile()
  await binding.sender.setParameters(parameters)
  if (!valid()) throw abortProfile()
}
