import type { ScreenDiagnostics } from '../screen_diagnostics'
import type { ScreenProfile } from '../screen_profile/policy'
import { runRepair, runStart, runUpdate, type ScreenPublisherOperations } from './operations'
import { emptyResolve, ScreenPublisherOperationError, type ActiveScreenPublication, type ScreenPublishIntent, type ScreenPublisherScope } from './types'

export { ScreenPublisherOperationError, type ScreenPublisherOutcome, type ScreenPublisherPort } from './types'
export type ScreenPublisherStopResult = 'complete' | 'cleanup-pending'

export class ScreenPublisherAdapter<T> implements ScreenPublisherOperations<T> {
  private revision = 0
  intent: 'start' | 'update' | 'repair' | 'stop' = 'stop'
  private running?: Promise<ScreenDiagnostics>
  private runningKind?: ScreenPublishIntent<T>['kind']
  private pending?: ScreenPublishIntent<T>
  active: ActiveScreenPublication<T> | undefined
  constructor(private readonly current: () => ScreenPublisherScope<T> | null) {}
  get currentRevision(): number { return this.revision }
  get stopping(): boolean { return this.intent === 'stop' }

  start(profile: ScreenProfile): Promise<ScreenDiagnostics> {
    return this.active ? this.update(profile) : this.submit('start', profile)
  }
  update(profile: ScreenProfile): Promise<ScreenDiagnostics> { return this.submit('update', profile) }
  repairCurrent(): Promise<ScreenDiagnostics> {
    return this.active ? this.submit('repair', this.active.profile) : Promise.reject(this.abort('cancel'))
  }

  stop(): Promise<ScreenPublisherStopResult> {
    if (this.intent === 'stop' && !this.active) {
      if (this.runningKind === 'start') return Promise.resolve('cleanup-pending')
      if (this.running) return this.running.catch(() => undefined).then(() => 'complete')
      return Promise.resolve('complete')
    }
    const pickerPending = !this.active && Boolean(this.running) && this.intent === 'start'
    ++this.revision; this.intent = 'stop'
    this.pending?.reject(this.abort('cancel')); this.pending = undefined
    const active = this.active, scope = active?.scope ?? this.current(); this.active = undefined
    const stopping = scope ? scope.port.stop(active?.track) : Promise.resolve()
    if (pickerPending) return stopping.then(() => 'cleanup-pending')
    return Promise.all([stopping, this.running?.catch(() => undefined)]).then(() => 'complete')
  }
  cancel(): void {
    ++this.revision; this.intent = 'stop'; this.active = undefined
    this.pending?.reject(this.abort('cancel')); this.pending = undefined
  }

  submitForEndedEvent(): Promise<void> {
    const active = this.active, scope = active?.scope ?? this.current(); this.cancel()
    return scope ? scope.port.stop(active?.track) : Promise.resolve()
  }

  private submit(kind: ScreenPublishIntent<T>['kind'], profile: ScreenProfile): Promise<ScreenDiagnostics> {
    const scope = this.current()
    if (!scope) return Promise.reject(this.abort('cancel'))
    const request = this.makeIntent(kind, profile, scope)
    if (this.running) {
      this.pending?.reject(this.abort('superseded')); this.pending = request
      return new Promise((resolve, reject) => { request.resolve = resolve; request.reject = reject })
    }
    return this.execute(request)
  }
  private makeIntent(kind: ScreenPublishIntent<T>['kind'], profile: ScreenProfile, scope: ScreenPublisherScope<T>): ScreenPublishIntent<T> {
    const revision = ++this.revision; this.intent = kind
    return { kind, profile, scope, revision, resolve: emptyResolve, reject: emptyResolve }
  }
  private execute(request: ScreenPublishIntent<T>): Promise<ScreenDiagnostics> {
    const operation = request.kind === 'start' ? runStart(this, request) : request.kind === 'repair' ? runRepair(this, request) : runUpdate(this, request)
    this.running = operation; this.runningKind = request.kind
    operation.then(value => this.finish(operation, request, value), error => this.finish(operation, request, undefined, error))
    return operation
  }
  private finish(operation: Promise<ScreenDiagnostics>, request: ScreenPublishIntent<T>, value?: ScreenDiagnostics, error?: unknown): void {
    if (this.running !== operation) return
    this.running = undefined; this.runningKind = undefined
    if (request.resolve !== emptyResolve) error === undefined ? request.resolve(value!) : request.reject(error)
    const next = this.pending; this.pending = undefined
    if (next) this.execute(next).then(next.resolve, next.reject)
  }
  valid(revision: number, scope: ScreenPublisherScope<T>): boolean {
    const now = this.current(); return revision === this.revision && now?.owner === scope.owner && now.room === scope.room && now.port === scope.port
  }
  abort(outcome: 'cancel' | 'superseded' = this.stopping ? 'cancel' : 'superseded'): ScreenPublisherOperationError {
    return new ScreenPublisherOperationError(outcome, 'Операция демонстрации отменена или заменена более новой.')
  }
}
