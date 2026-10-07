import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { profileDimensions, profileScale, screenProfile, screenShareMaxBitrate } from '../screen_profile/policy'
import type { ScreenFrameRate, ScreenProfile, ScreenResolution } from '../screen_profile/policy'

const catalog = JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-profile-v1.catalog.json', import.meta.url), 'utf8'))
const fixtures = JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8'))
const schema = JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-profile-v1.schema.json', import.meta.url), 'utf8'))

describe('screen-share contract v1', () => {
  it('keeps bounded lifecycle states and descriptor schema version aligned', () => {
    expect(schema.properties.schema_version.const).toBe(1)
    expect(schema.properties.publisher_state.enum).toEqual(catalog.states.publisher)
    expect(schema.properties.viewer_state.enum).toEqual(catalog.states.viewer)
    expect(schema.properties.reason_codes.items.enum).toEqual(catalog.reasonCodes)
    expect(schema.properties.requested_profile_id.enum).toEqual([
      ...catalog.existingProfiles.map((profile: { id: string }) => profile.id),
      ...catalog.experimentCandidates.map((profile: { id: string }) => profile.id),
    ])
    expect(schema.required).toContain('scope')
    expect(schema.properties.scope.required).toEqual(['origin_id', 'account_id', 'room_id', 'media_session_id', 'publication_generation', 'operation_revision'])
    expect(schema.properties.effective_profile.properties.encoding.properties.layers.maxItems).toBe(2)
    expect(catalog.topologyPolicy.selectedVideoSubscriptionsPerViewer).toBe(1)
    expect(catalog.topologyPolicy.maximumLayers).toBe(2)
    expect(catalog.topologyPolicy.dynacastOwner).toBe('LiveKit/WebRTC SDK')
    expect(catalog.topologyPolicy.currentSourceDerivedByRuntime.web).toMatchObject({ simulcast: true, primaryLayers: { min: 1, max: 2 }, lowLayerMaxFps: 15, evidenceStatus: 'source-derived-unvalidated' })
    expect(catalog.topologyPolicy.currentSourceDerivedByRuntime.flutterAndroid).toMatchObject({ simulcast: false, primaryLayers: { min: 1, max: 1 }, evidenceStatus: 'source-derived-unvalidated' })
    expect(catalog.topologyPolicy.currentSourceDerivedByRuntime.flutterIOS.defaultProfileId).toBe('P720_15')
    expect(catalog.topologyPolicy.currentSourceDerivedByRuntime.flutterDesktop.primaryLayers.max).toBe(2)
    expect(catalog.topologyPolicy.backupCodecEvidenceStatus).toBe('sfu-negotiated-unvalidated')
    expect(fixtures.schemaVersion).toBe(schema.properties.schema_version.const)
    expect(fixtures.descriptorCompatibility).toEqual([
      expect.objectContaining({ descriptorVersion: null, legacyTrackReadable: true, v1ControlsEnabled: false, fallbackAttempts: 0 }),
      expect.objectContaining({ descriptorVersion: 1, legacyTrackReadable: true, v1ControlsEnabled: true, fallbackAttempts: 0 }),
      expect.objectContaining({ descriptorVersion: 99, legacyTrackReadable: true, v1ControlsEnabled: false, fallbackAttempts: 0 }),
    ])
    for (const fixture of fixtures.enumValidation) {
      const accepted = schema.properties[fixture.property]?.enum?.includes(fixture.value) ?? false
      expect(accepted).toBe(fixture.accepted)
    }
    const stopped = fixtures.lifecycle.find((fixture: { name: string }) => fixture.name.startsWith('stop-'))
    expect(stopped.operationRevision).toBeGreaterThan(stopped.completionRevision)
    expect(stopped.expectedOutcome).toBe('superseded')
    expect(stopped.mayPublish).toBe(false)
    const revoked = fixtures.lifecycle.find((fixture: { name: string }) => fixture.name.startsWith('revoke-'))
    expect(revoked.expectedOutcome).toBe('session-revoked')
    expect(revoked.mayPublish).toBe(false)
    const reconnect = fixtures.lifecycle.find((fixture: { name: string }) => fixture.name.startsWith('reconnect-'))
    expect(reconnect.newGeneration).toBeGreaterThan(reconnect.oldGeneration)
    expect(reconnect.recapture).toBe(false)
  })

  it('preserves every existing profile key and stores bitrates in bit/s', () => {
    expect(catalog.units.bitrate).toBe('bit/s')
    for (const profile of catalog.existingProfiles) {
      expect(profile.id).toBe(`P${profile.resolution}_${profile.frameRate}`)
      expect(screenShareMaxBitrate(profile.resolution, profile.frameRate)).toBe(profile.bitrateBps)
    }
    expect(catalog.experimentCandidates.find((p: { id: string }) => p.id === 'motion-1440p60-v1')?.evidenceStatus).toBe('research-only')
  })

  it('rejects profiles outside the versioned catalog', () => {
    expect(() => screenProfile('P999_30' as ScreenProfile)).toThrow('Некорректный профиль')
    expect(() => screenShareMaxBitrate(999 as ScreenResolution, 30 as ScreenFrameRate)).toThrow('Некорректный профиль')
    expect(() => screenShareMaxBitrate(1080, 90 as ScreenFrameRate)).toThrow('Некорректный профиль')
  })

  it('matches aspect-preserving geometry fixtures including portrait, ultrawide and odd edges', () => {
    for (const fixture of fixtures.geometry) {
      const profile = `P${fixture.resolution}_${fixture.frameRate}` as ScreenProfile
      const source = { width: fixture.source.width, height: fixture.source.height }
      const target = profileDimensions(profile, source)
      const scale = profileScale(profile, source)
      const width = Math.floor(source.width / scale)
      const height = Math.floor(source.height / scale)

      expect(scale).toBeGreaterThanOrEqual(1)
      expect({ width, height }).toEqual(fixture.expectedEncoded)
      expect(width).toBeLessThanOrEqual(target.width)
      expect(height).toBeLessThanOrEqual(target.height)
      if (source.width >= 2 && source.height >= 2) {
        expect(width % 2).toBe(0)
        expect(height % 2).toBe(0)
      }
      expect(width / height).toBeCloseTo(source.width / source.height, 2)
    }
  })
})
