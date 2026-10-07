import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const read = (name: string) => JSON.parse(readFileSync(new URL(`../../../../../contracts/screen-share-profile-v1.${name}.json`, import.meta.url), 'utf8'))
const catalog = read('catalog')
const schema = read('schema')
const fixtures = read('fixtures')

function accepts(descriptor: Record<string, any>): boolean {
  const properties = schema.properties
  const required = schema.required.every((key: string) => key in descriptor)
  const knownKeys = Object.keys(descriptor).every((key: string) => key in properties) || schema.additionalProperties
  const enumValue = (key: string, value: unknown) => properties[key]?.enum?.includes(value) ?? true
  const scope = descriptor.scope ?? {}
  const layers = descriptor.effective_profile?.encoding?.layers ?? []
  const profileMatchesMode = descriptor.requested_profile_id.startsWith('text-')
    ? descriptor.mode === 'text' : !descriptor.requested_profile_id.startsWith('motion-') || descriptor.mode === 'motion'
  return required && knownKeys && descriptor.schema_version === properties.schema_version.const
    && enumValue('mode', descriptor.mode) && enumValue('publisher_state', descriptor.publisher_state)
    && enumValue('viewer_state', descriptor.viewer_state) && enumValue('layer_topology', descriptor.layer_topology)
    && enumValue('requested_profile_id', descriptor.requested_profile_id)
    && schema.properties.reason_codes.items.enum && descriptor.reason_codes.every((code: string) => schema.properties.reason_codes.items.enum.includes(code))
    && schema.properties.scope.required.every((key: string) => typeof scope[key] === (key.endsWith('_revision') || key.endsWith('_generation') ? 'number' : 'string') && (typeof scope[key] !== 'string' || scope[key].length > 0))
    && profileMatchesMode && descriptor.profile_revision >= 0
    && layers.length >= 1 && layers.length <= schema.properties.effective_profile.properties.encoding.properties.layers.maxItems
}

describe('screen-share contract acceptance fixtures', () => {
  it('reads legacy publication names without granting a second stream', () => {
    const legacyPattern = new RegExp(catalog.compatibility.legacyPublicationPattern)
    const knownProfiles = new Set(catalog.existingProfiles.map((profile: { id: string }) => profile.id))
    for (const fixture of fixtures.legacyPublicationNames) {
      const match = legacyPattern.exec(fixture.name)
      const profileId = match ? `P${match[1]}_${match[2]}` : null
      expect(profileId !== null && profileId === fixture.profileId && knownProfiles.has(profileId)).toBe(fixture.accepted)
    }
    expect(catalog.targetPolicy.selectedVideoSubscriptionsPerViewer).toBe(1)
  })

  it('accepts only the versioned descriptor samples in the shared fixture', () => {
    for (const sample of fixtures.descriptorCases) {
      expect(accepts({ ...fixtures.validDescriptor, ...sample.overrides }), sample.name).toBe(sample.accepted)
    }
  })

  it('keeps cancellation, rollback and retry generations explicit', () => {
    const lifecycle = (name: string) => fixtures.lifecycle.find((item: { name: string }) => item.name === name)
    expect(fixtures.lifecycle.map((item: { name: string }) => item.name)).toEqual(expect.arrayContaining([
      'stop-invalidates-pending-update', 'revoke-wins-pending-start', 'logout-invalidates-pending-start',
      'publish-failure-rolls-back-screen-only', 'reconnect-reuses-capture', 'retry-keeps-generation', 'new-user-start-gets-session',
    ]))
    for (const item of fixtures.lifecycle.filter((value: { mayPublish?: boolean }) => value.mayPublish === false)) {
      expect(item.mayPublish).toBe(false)
    }
    expect(lifecycle('stop-invalidates-pending-update').operationRevision).toBeGreaterThan(lifecycle('stop-invalidates-pending-update').completionRevision)
    expect(lifecycle('revoke-wins-pending-start').revoked).toBe(true)
    expect(lifecycle('logout-invalidates-pending-start')).toMatchObject({ loggedOut: true, reasonCode: 'logout', mayPublish: false })
    expect(lifecycle('publish-failure-rolls-back-screen-only')).toMatchObject({ screenTracksReleased: true, microphoneReleased: false, voiceMembershipReleased: false })
    const reconnect = lifecycle('reconnect-reuses-capture')
    expect(reconnect.newGeneration).toBeGreaterThan(reconnect.oldGeneration)
    expect(reconnect).toMatchObject({ mediaSessionId: 'share-a', recapture: false })
    expect(lifecycle('retry-keeps-generation')).toMatchObject({ oldGeneration: 4, newGeneration: 4, recapture: false })
    expect(lifecycle('restart-after-source-ended')).toMatchObject({ oldGeneration: 4, newGeneration: 5, recapture: true, userActionRequired: true })
    expect(lifecycle('new-user-start-gets-session')).toMatchObject({ oldMediaSessionId: 'share-a', mediaSessionId: 'share-b', newGeneration: 0, recapture: true })
  })

  it('declares a single-layer default, bounded opt-in simulcast and reproducible measured gates', () => {
    expect(catalog.targetPolicy).toMatchObject({ selectedVideoSubscriptionsPerViewer: 1, defaultRequestedProfileId: 'P1080_60', defaultTopology: 'single-layer', simulcast: { enabledByDefault: false, maxLayers: 2 }, congestionControlOwner: 'LiveKit/WebRTC SDK', forceMinimumBitrate: false, periodicKeyframes: false })
    expect(catalog.qualityAcceptance).toMatchObject({ status: 'proposed-unvalidated', warmupSeconds: 30, durationSeconds: 180, windowSeconds: 1, repeats: 5, presentedFpsP05: 55, latencyP95Ms: { firstFrame: 2000, profileSwitch: 2000 }, freezeThresholdMs: 500 })
    expect(catalog.qualityAcceptance.fpsObservation).toContain('presented')
    expect(catalog.rollout.fallbackAttemptsPerGeneration).toBe(1)
    expect(catalog.rollout.descriptorMetadata).toMatchObject({
      featureSwitch: 'screen-share.descriptor-v1', independentlyDisableable: true,
      webBuildVariable: 'VITE_SCREEN_SHARE_DESCRIPTOR_V1', defaultEnabled: true,
    })
    expect(catalog.rollout.boundedSimulcast).toMatchObject({
      featureSwitch: 'screen-share.bounded-simulcast', independentlyDisableable: true,
      webBuildVariable: 'VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', defaultEnabled: false,
    })
  })
})
