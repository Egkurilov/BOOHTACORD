import catalog from '../../../../../contracts/screen-share-profile-v1.catalog.json' with { type: 'json' }

const profile = catalog.experimentCandidates.find(candidate => candidate.id === 'motion-1080p60-v1')
const resolution = profile && catalog.resolutions.find(value => value.height === profile.resolution)
if (!profile || !resolution || profile.selectedBitrateBps === null) throw new Error('screen-share baseline profile is unavailable')

export const baselinePlan = {
  profileId: profile.id,
  width: resolution.width,
  height: resolution.height,
  frameRate: profile.frameRate,
  bitrateBps: profile.selectedBitrateBps,
  codec: 'vp8' as const,
  layers: 1,
}

export const measurementPlan = { warmupMs: 30000, sampleMs: 180000, windowMs: 1000, repeats: 5 }
