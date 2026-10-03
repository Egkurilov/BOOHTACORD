import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { ChannelKind } from '../topology_client'

export interface CommandResult { clientRequestId: string; topologyRevision: number; resourceType: 'CATEGORY' | 'TEXT_CHANNEL' | 'VOICE_CHANNEL'; resourceId: string; state: 'ACTIVE' | 'ARCHIVED' | 'DELETED' | 'CLOSING' }
export type MutationRequest = (input: string, init: RequestInit) => Promise<Response>
export class TopologyMutationError extends Error {
  constructor(message: string, readonly status: number, readonly code: string) { super(message) }
}
function record(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('Сервер вернул некорректный результат команды.')
  return value as Record<string, unknown>
}
function parse(value: unknown): CommandResult {
  const source = record(value); const result = record(source.result)
  const type = result.resource_type; const state = result.state
  if (typeof source.client_request_id !== 'string' || !Number.isInteger(source.topology_revision) || (source.topology_revision as number) < 1 || !['CATEGORY', 'TEXT_CHANNEL', 'VOICE_CHANNEL'].includes(type as string) || typeof result.resource_id !== 'string' || !['ACTIVE', 'ARCHIVED', 'DELETED', 'CLOSING'].includes(state as string)) throw new Error('Сервер вернул некорректный результат команды.')
  return { clientRequestId: source.client_request_id, topologyRevision: source.topology_revision as number, resourceType: type as CommandResult['resourceType'], resourceId: result.resource_id, state: state as CommandResult['state'] }
}
async function failure(response: Response): Promise<TopologyMutationError> {
  try {
    const body = record(await response.json()); const error = record(body.error)
    if (typeof error.message === 'string' && typeof error.code === 'string') return new TopologyMutationError(error.message, response.status, error.code)
  } catch { /* bounded fallback */ }
  return new TopologyMutationError(`Не удалось изменить каналы (${response.status}).`, response.status, 'REQUEST_FAILED')
}
async function command(path: string, method: 'POST' | 'DELETE', body: Record<string, unknown>, request: MutationRequest): Promise<CommandResult> {
  const response = await request(`${apiBaseUrl}${path}`, { method, credentials: 'same-origin', headers: { accept: 'application/json', 'content-type': 'application/json' }, body: JSON.stringify(body) })
  if (!response.ok) throw await failure(response)
  return parse(await response.json())
}
export function createMemberCategory(name: string, clientRequestId: string, request: MutationRequest = tracedFetch): Promise<CommandResult> {
  return command('/categories', 'POST', { name, client_request_id: clientRequestId }, request)
}
export function createMemberChannel(categoryId: string, name: string, kind: ChannelKind, clientRequestId: string, request: MutationRequest = tracedFetch): Promise<CommandResult> {
  return command(`/categories/${encodeURIComponent(categoryId)}/channels`, 'POST', { name, kind, client_request_id: clientRequestId }, request)
}
export function deleteCategory(categoryId: string, revision: number, clientRequestId: string, request: MutationRequest = tracedFetch): Promise<CommandResult> {
  return command(`/categories/${encodeURIComponent(categoryId)}`, 'DELETE', { expected_revision: revision, confirm_delete: true, client_request_id: clientRequestId }, request)
}
export function archiveText(channelId: string, revision: number, clientRequestId: string, request: MutationRequest = tracedFetch): Promise<CommandResult> {
  return command(`/channels/${encodeURIComponent(channelId)}`, 'DELETE', { expected_revision: revision, confirm_archive: true, client_request_id: clientRequestId }, request)
}
export function closeVoice(channelId: string, revision: number, clientRequestId: string, request: MutationRequest = tracedFetch): Promise<CommandResult> {
  return command(`/voice-channels/${encodeURIComponent(channelId)}/close-admission`, 'POST', { expected_revision: revision, confirm_close: true, client_request_id: clientRequestId }, request)
}
