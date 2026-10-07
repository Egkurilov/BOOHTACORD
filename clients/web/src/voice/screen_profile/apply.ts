import { profileDimensions, screenProfile, type ScreenProfile } from './policy'
import { abortProfile, sameBinding, trackBinding, type ProfileTrack } from './types'

export async function applyScreenProfile(track: ProfileTrack, profile: ScreenProfile, current: () => boolean = () => true): Promise<void> {
  const binding = trackBinding(track), target = screenProfile(profile)
  const valid = () => current() && sameBinding(track, binding)
  if (!valid()) throw abortProfile()
  const dimensions = profileDimensions(profile, binding.capture.getSettings())
  await binding.capture.applyConstraints({ width: { max: dimensions.width }, height: { max: dimensions.height }, frameRate: { max: target.frameRate } })
  if ('contentHint' in binding.capture) binding.capture.contentHint = target.frameRate === 60 ? 'motion' : 'text'
  if (!valid()) throw abortProfile()
}
