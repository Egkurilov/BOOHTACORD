import { ScreenPublisherOperationError, type ActiveScreenPublication, type ScreenPublishIntent, type ScreenPublisherScope } from './types'
import type { ScreenDiagnostics } from '../screen_diagnostics'

export interface ScreenPublisherOperations<T> {
  valid(revision: number, scope: ScreenPublisherScope<T>): boolean
  abort(): ScreenPublisherOperationError
  get currentRevision(): number
  active: ActiveScreenPublication<T> | undefined
  get intent(): 'start' | 'update' | 'repair' | 'stop'
  get stopping(): boolean
}

export async function runStart<T>(ctx: ScreenPublisherOperations<T>, request: ScreenPublishIntent<T>): Promise<ScreenDiagnostics> {
  const { revision, scope, profile } = request
  if (!ctx.valid(revision, scope)) throw ctx.abort()
  let track: T | undefined, cleanupAttempted = false
  try {
    track = await scope.port.start(profile)
    if (!track) throw new ScreenPublisherOperationError('cancel', 'Выбор экрана отменён до создания публикации.')
    ctx.active = { scope, track, profile, generation: scope.port.generation(), repairAttempts: 0 }
    if (!ctx.valid(revision, scope)) {
      cleanupAttempted = true; ctx.active = undefined
      try { await scope.port.stop(track) } catch (cleanupCause) {
        throw new ScreenPublisherOperationError('failure', 'Не удалось очистить отменённую публикацию демонстрации.', 'cleanup-required', cleanupCause)
      }
      throw ctx.abort()
    }
    if (scope.port.currentTrack() !== track) throw new ScreenPublisherOperationError('failure', 'LiveKit не подтвердил публикацию демонстрации.')
    scope.port.adopt?.(profile)
    const diagnostics = await scope.port.diagnostics()
    if (!ctx.valid(revision, scope)) throw ctx.abort()
    return diagnostics
  } catch (cause) {
    let cleanupCause: unknown
    if (!cleanupAttempted) {
      if (ctx.active?.track === track) ctx.active = undefined
      try { await scope.port.stop(track); cleanupAttempted = true } catch (error) { cleanupCause = error }
    }
    if (cleanupCause !== undefined) {
      throw new ScreenPublisherOperationError('failure', 'Не удалось очистить неудачную публикацию демонстрации.', 'cleanup-required', { cause, cleanupCause })
    }
    if (cause instanceof ScreenPublisherOperationError) throw cause
    if (cause instanceof Error && cause.name === 'AbortError') throw new ScreenPublisherOperationError('cancel', 'Выбор экрана отменён.', undefined, cause)
    throw new ScreenPublisherOperationError('failure', 'Не удалось запустить демонстрацию экрана.', undefined, cause)
  }
}

export async function runUpdate<T>(ctx: ScreenPublisherOperations<T>, request: ScreenPublishIntent<T>): Promise<ScreenDiagnostics> {
  const { revision, scope, profile } = request, active = ctx.active, abort = () => ctx.abort()
  if (!active || !sameScope(active, scope) || !scope.port.isLive(active.track) || (scope.port.currentTrack() && scope.port.currentTrack() !== active.track) || active.generation !== scope.port.generation()) throw abort()
  const previous = active.profile
  let publicationMutation = false
  try {
    await scope.port.capture(active.track, profile)
    if (!ctx.valid(revision, scope) || active.generation !== scope.port.generation() || (scope.port.currentTrack() && scope.port.currentTrack() !== active.track)) throw abort()
    publicationMutation = true
    if (scope.port.currentTrack() === active.track) { await scope.port.unpublish(active.track, false); active.generation = scope.port.generation() }
    if (!ctx.valid(revision, scope)) throw abort()
    await scope.port.publish(active.track, profile)
    active.profile = profile; active.generation = scope.port.generation()
    if (profile !== previous) active.repairAttempts = 0
    if (!ctx.valid(revision, scope)) { if (ctx.stopping) await scope.port.stop(active.track); throw abort() }
    if (scope.port.currentTrack() !== active.track) throw new ScreenPublisherOperationError('failure', 'LiveKit не подтвердил обновлённую публикацию.')
    scope.port.adopt?.(profile)
    const diagnostics = await scope.port.diagnostics()
    if (!ctx.valid(revision, scope)) throw abort()
    return diagnostics
  } catch (cause) {
    if (revision !== ctx.currentRevision || ctx.stopping) {
      if (ctx.stopping && publicationMutation) { ctx.active = undefined; await scope.port.stop(active.track).catch(() => {}) }
      throw cause instanceof ScreenPublisherOperationError ? cause : abort()
    }
    try {
      await scope.port.capture(active.track, previous)
      if (publicationMutation) {
        const published = scope.port.currentTrack()
        if (published && published !== active.track) throw abort()
        if (published === active.track) await scope.port.unpublish(active.track, false)
        await scope.port.publish(active.track, previous)
      }
      active.profile = previous; active.generation = scope.port.generation(); scope.port.adopt?.(previous)
    } catch (rollbackCause) {
      ctx.active = undefined; await scope.port.stop(active.track).catch(() => {})
      throw new ScreenPublisherOperationError('failure', 'Профиль демонстрации не применён; восстановить прежнюю конфигурацию не удалось.', 'cleanup-required', { cause, rollbackCause })
    }
    throw new ScreenPublisherOperationError('failure', 'Не удалось изменить профиль демонстрации; прежняя конфигурация восстановлена.', 'restored', cause)
  }
}

export async function runRepair<T>(ctx: ScreenPublisherOperations<T>, request: ScreenPublishIntent<T>): Promise<ScreenDiagnostics> {
  const { revision, scope, profile } = request, active = ctx.active
  if (!active || !sameScope(active, scope) || !scope.port.isLive(active.track) || scope.port.currentTrack() !== active.track) throw ctx.abort()
  if (active.repairAttempts > 0 || !scope.port.repair) return scope.port.diagnostics()
  let repaired: boolean
  try { repaired = await scope.port.repair(active.track, profile, () => ctx.valid(revision, scope)) }
  catch (cause) {
    if (ctx.stopping || revision !== ctx.currentRevision) throw ctx.abort()
    ctx.active = undefined; await scope.port.stop(active.track).catch(() => {})
    throw new ScreenPublisherOperationError('failure', 'Не удалось восстановить публикацию профиля демонстрации.', 'cleanup-required', cause)
  }
  if (!ctx.valid(revision, scope)) throw ctx.abort()
  if (repaired) { active.repairAttempts++; active.generation = scope.port.generation() }
  const diagnostics = await scope.port.diagnostics()
  if (!ctx.valid(revision, scope)) throw ctx.abort()
  return diagnostics
}

function sameScope<T>(active: ActiveScreenPublication<T>, scope: ScreenPublisherScope<T>): boolean {
  return active.scope.owner === scope.owner && active.scope.room === scope.room && active.scope.port === scope.port
}
