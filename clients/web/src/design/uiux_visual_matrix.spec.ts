import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { ux2026ReferenceViewports, ux2026RequiredViewports, ux2026ShellViewports } from '../../tests/uiux_2026/viewport_matrix'

type MatrixEntry = {
  id: string
  surface: 'desktop' | 'mobile'
  referenceAsset: string
  referenceStatus: 'PRESENT_IN_ARCHIVE'
  targetViewport: { width: number; height: number }
  referenceRasterPx: { width: number; height: number }
  fixture: string
  testFile: string
  flutterTestFile: string
  interaction: string
  expectedOrException: string
  owner: string
  sourceComparisonStatus?: string
}

type VisualMatrix = {
  issue: string
  expectedCount: number
  sourceArchive: string
  sourceArchiveSha256: string
  sourceArchiveStatus: string
  sourceIntegrityFindings: Array<{
    asset: string
    duplicateOf: string
    sha256: string
    status: string
  }>
  screens: MatrixEntry[]
}

const repoRoot = resolve(fileURLToPath(new URL('../../../..', import.meta.url)))
const matrixPath = new URL('../../tests/uiux_2026/visual_matrix.json', import.meta.url)

describe('UIUX-2026 visual regression inventory', () => {
  it('runs the required viewport matrix and captures each required target size', () => {
    const shellViewports = new Set(ux2026ShellViewports.map(({ width, height }) => `${width}x${height}`))
    const screenshotViewports = new Set(ux2026RequiredViewports.map(({ width, height }) => `${width}x${height}`))
    const sourceViewports = new Set(ux2026ReferenceViewports.map(({ width, height }) => `${width}x${height}`))

    expect([...screenshotViewports]).toEqual(['320x640', '390x844', '768x1024', '1024x768', '1440x900', '1920x1080'])
    expect([...sourceViewports]).toEqual(['1440x900', '393x852'])
    for (const viewport of [...screenshotViewports, ...sourceViewports]) expect(shellViewports.has(viewport), `${viewport} is swept`).toBe(true)
  })

  it('catalogues all 41 desktop and mobile reference slots', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix

    expect(matrix.issue).toBe('Egkurilov/BOOHTACORD#289')
    expect(matrix.sourceArchiveStatus).toContain('41 PNG entries verified')
    expect(matrix.expectedCount).toBe(41)
    expect(matrix.screens).toHaveLength(41)
    expect(matrix.screens.filter(({ surface }) => surface === 'desktop')).toHaveLength(18)
    expect(matrix.screens.filter(({ surface }) => surface === 'mobile')).toHaveLength(23)
    expect(matrix.screens.every(({ referenceAsset }) => referenceAsset.length > 0)).toBe(true)
    expect(new Set(matrix.screens.map(({ id }) => id)).size).toBe(41)
    expect(new Set(matrix.screens.map(({ referenceAsset }) => referenceAsset)).size).toBe(41)

    expect(existsSync(resolve(repoRoot, matrix.sourceArchive))).toBe(true)
  })

  it('maps each slot to an existing test surface, viewport, expected result, and owner', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix

    for (const entry of matrix.screens) {
      expect(entry.id).toMatch(/^(D|M)\d{2}$/)
      expect(entry.fixture.length, `${entry.id} fixture`).toBeGreaterThan(0)
      expect(entry.testFile.length, `${entry.id} test file`).toBeGreaterThan(0)
      expect(entry.flutterTestFile.length, `${entry.id} Flutter test file`).toBeGreaterThan(0)
      expect(entry.interaction.length, `${entry.id} interaction`).toBeGreaterThan(0)
      expect(entry.expectedOrException.length, `${entry.id} expected result`).toBeGreaterThan(0)
      expect(entry.owner.length, `${entry.id} owner`).toBeGreaterThan(0)
      expect(existsSync(resolve(repoRoot, entry.fixture)), `${entry.id} fixture exists`).toBe(true)
      expect(existsSync(resolve(repoRoot, entry.testFile)), `${entry.id} test file exists`).toBe(true)
      expect(existsSync(resolve(repoRoot, entry.flutterTestFile)), `${entry.id} Flutter test file exists`).toBe(true)
      expect(entry.targetViewport.width).toBeGreaterThan(0)
      expect(entry.targetViewport.height).toBeGreaterThan(0)
      expect(entry.targetViewport).toEqual(entry.surface === 'desktop'
        ? { width: 1440, height: 900 }
        : { width: 393, height: 852 })
      expect(entry.referenceRasterPx).toEqual(entry.surface === 'desktop'
        ? { width: 2880, height: 1800 }
        : entry.referenceAsset.includes('stream-launch')
          ? { width: 786, height: 1704 }
          : { width: 1179, height: 2556 })

      expect(entry.referenceAsset).toMatch(/^(desktop|mobile)-.+\.png$/)
      expect(entry.referenceStatus).toBe('PRESENT_IN_ARCHIVE')
    }
  })

  it('maps guild settings to the admin settings flow and marks the duplicated desktop source', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix
    const desktop = matrix.screens.find(({ referenceAsset }) => referenceAsset === 'desktop-guild-settings.png')!
    const mobile = matrix.screens.find(({ referenceAsset }) => referenceAsset === 'mobile-guild-settings.png')!

    expect(matrix.sourceIntegrityFindings).toEqual([{
      asset: 'desktop-guild-settings.png',
      duplicateOf: 'desktop-guild-members.png',
      sha256: '0a0ba90ad3288815fa4925b540396e74defaf463f4542fe38c6370c5ff57ff57',
      status: 'BLOCKED_DUPLICATE_BASELINE',
    }])
    for (const entry of [desktop, mobile]) {
      expect(entry.fixture).toBe('clients/web/tests/guild_lifecycle/fixture.html')
      expect(entry.testFile).toBe('clients/web/tests/guild_lifecycle/guild.browser.spec.ts')
      expect(entry.owner).toBe('clients/web/src/admin/guild_settings/AdminGuildSettings.vue')
      expect(entry.flutterTestFile).toBe('clients/flutter/test/admin_guild_settings_test.dart')
      expect(entry.interaction).toContain('Настройки гильдии')
    }
    expect(desktop.sourceComparisonStatus).toBe('BLOCKED_DUPLICATE_BASELINE')
    expect(desktop.expectedOrException).toContain('desktop-guild-members.png')
  })
})
