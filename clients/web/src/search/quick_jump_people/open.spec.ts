import { expect, it, vi } from 'vitest'
import { DirectMessageCandidateRequestError } from '../../direct_message/direct_message_candidate_client'
import { createQuickJumpOpen } from './open'

function fixture() {
  const state = { dialogs: [] as { id: string }[], denied: false }
  const ports = { channels: () => [], refreshChannels: vi.fn(async () => {}), channelError: () => false,
    dialogs: () => state.dialogs, refreshDialogs: vi.fn(async () => {}), dialogError: () => state.denied,
    channel: vi.fn(), dialog: vi.fn(), error: vi.fn() }
  return { state, ports }
}
it('opens an eligible member only after the server returns an accessible dialog', async () => {
  const { state, ports } = fixture()
  const member = vi.fn(async () => { state.dialogs = [{ id: 'dm' }]; return { id: 'dm', participantOneId: 'self', participantTwoId: 'member', createdAt: '' } })
  await createQuickJumpOpen(ports, member).open({ kind: 'MEMBER', id: 'member' })
  expect(member).toHaveBeenCalledWith('member')
  expect(ports.refreshDialogs).toHaveBeenCalledOnce()
  expect(ports.dialog).toHaveBeenCalledWith('dm')
  expect(ports.channel).not.toHaveBeenCalled()
})
it('rejects stale cached dialogs when the authoritative refresh fails', async () => {
  const { state, ports } = fixture(); state.dialogs = [{ id: 'dm' }]; state.denied = true
  await createQuickJumpOpen(ports).open({ kind: 'DIRECT_MESSAGE', id: 'dm' })
  expect(ports.dialog).not.toHaveBeenCalled()
  expect(ports.error).toHaveBeenLastCalledWith('Личный диалог больше недоступен.')
})
for (const status of [403, 404]) {
  it(`reports an unavailable DM for an explicit ${status} response`, async () => {
    const { ports } = fixture()
    const member = vi.fn(async () => { throw new DirectMessageCandidateRequestError(status) })
    await createQuickJumpOpen(ports, member).open({ kind: 'MEMBER', id: 'member' })
    expect(ports.dialog).not.toHaveBeenCalled()
    expect(ports.error).toHaveBeenLastCalledWith('Личный диалог больше недоступен.')
  })
}
it('disposal discards a late member response before navigation', async () => {
  const { ports } = fixture()
  let resolve!: (value: { id: string; participantOneId: string; participantTwoId: string; createdAt: string }) => void
  const opener = createQuickJumpOpen(ports, () => new Promise(r => { resolve = r }))
  const pending = opener.open({ kind: 'MEMBER', id: 'member' }); opener.dispose()
  resolve({ id: 'dm', participantOneId: 'self', participantTwoId: 'member', createdAt: '' }); await pending
  expect(ports.dialog).not.toHaveBeenCalled(); expect(ports.refreshDialogs).not.toHaveBeenCalled()
})
