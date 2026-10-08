import { describe, expect, it, vi } from 'vitest'

vi.mock('../message_client', () => ({ loadMessagePage: vi.fn() }))
vi.mock('../../direct_message/direct_message_client', () => ({ loadDirectMessageHistory: vi.fn() }))

import { loadMessagePage } from '../message_client'
import { loadDirectMessageHistory } from '../../direct_message/direct_message_client'
import { loadConversationFilePage, mapConversationFiles, type ConversationFileMessage } from './files_panel'

function message(id: string, createdAt: string, attachments: ConversationFileMessage['attachments'], deleted = false): ConversationFileMessage {
  return { id, createdAt, deleted, attachments }
}

describe('conversation files projection', () => {
  it('loads each cursor page through its existing authenticated conversation history route', async () => {
    const textPage = { messages: [], nextCursor: 'text-cursor' }
    const dmPage = { messages: [], nextCursor: 'dm-cursor' }
    vi.mocked(loadMessagePage).mockResolvedValue(textPage)
    vi.mocked(loadDirectMessageHistory).mockResolvedValue(dmPage)

    await expect(loadConversationFilePage('CHANNEL', 'text-a', 'older-text')).resolves.toBe(textPage)
    await expect(loadConversationFilePage('DIRECT_MESSAGE', 'dm-a', 'older-dm')).resolves.toBe(dmPage)
    expect(loadMessagePage).toHaveBeenCalledWith('text-a', 'older-text')
    expect(loadDirectMessageHistory).toHaveBeenCalledWith('dm-a', 'older-dm')
  })

  it('keeps server metadata, labels the file type and points back to its message', () => {
    expect(mapConversationFiles([message('m-1', '2026-10-08T09:30:00Z', [
      { id: 'a-1', originalName: 'Раунд.PNG', sizeBytes: 2048 },
    ])])).toEqual([{
      id: 'a-1', originalName: 'Раунд.PNG', sizeBytes: 2048, messageId: 'm-1',
      createdAt: '2026-10-08T09:30:00Z', typeLabel: 'PNG',
    }])
  })

  it('omits deleted messages and duplicate attachments from overlapping cursor pages', () => {
    const attachment = { id: 'a-1', originalName: 'proof.pdf', sizeBytes: 5 }
    expect(mapConversationFiles([
      message('m-deleted', '2026-10-08T09:31:00Z', [attachment], true),
      message('m-1', '2026-10-08T09:30:00Z', [attachment]),
      message('m-1', '2026-10-08T09:30:00Z', [attachment]),
    ])).toHaveLength(1)
    expect(mapConversationFiles([message('m-plain', '2026-10-08T09:29:00Z', [{ ...attachment, originalName: 'blob' }])])[0]?.typeLabel).toBe('Файл')
  })
})
