import { expect, it } from 'vitest'
import { buildSenderScreenReport } from '../screen_client_reporter'
import { unknownScreenDiagnostics } from '../screen_diagnostics'
import { screenDiagnosticMessage } from '../screen_feedback'

it('reports measured capture and guard state separately from encoded dimensions', () => {
  const report = buildSenderScreenReport('desktop_web', { ...unknownScreenDiagnostics(), source: 'ACTIVE',
    measured: { width: 1280, height: 720, framesPerSecond: 20 },
    profileCheck: { status: 'adapted', reason: 'none', attempts: 0, captureWidth: 1920, captureHeight: 1080, captureFps: 60 },
  }, 'P1080_60')
  expect(report).toMatchObject({ target_resolution: 1080, target_fps: 60, frame_width: 1280, frame_height: 720,
    profile_check_status: 'adapted', profile_check_reason: 'none', profile_repair_attempts: 0,
    capture_width: 1920, capture_height: 1080, capture_fps: 60 })
})

it('omits unknown capture measurements and preserves the one-attempt warning', () => {
  const diagnostics = { ...unknownScreenDiagnostics(), profileCheck: { status: 'failed' as const, reason: 'configuration' as const, attempts: 1 } }
  const report = buildSenderScreenReport('desktop_web', diagnostics, 'P1080_60')!
  expect(report).toMatchObject({ profile_check_status: 'failed', profile_repair_attempts: 1 })
  expect(report).not.toHaveProperty('capture_width')
  expect(report).not.toHaveProperty('capture_fps')
  expect(screenDiagnosticMessage(diagnostics)).toContain('Не удалось удержать выбранное качество')
})
