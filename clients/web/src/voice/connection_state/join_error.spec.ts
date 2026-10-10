import { describe, expect, it } from 'vitest'

import { voiceJoinErrorMessage } from './join_error'

describe('voice join error copy', () => {
  it('explains a missing microphone and offers the listener path', () => {
    const error = Object.assign(new Error('Requested device not found'), { name: 'NotFoundError' })

    expect(voiceJoinErrorMessage(error)).toBe(
      'Микрофон не найден. Подключитесь без микрофона или подключите устройство и повторите попытку.',
    )
  })

  it('explains microphone constraints separately from permission denial', () => {
    const error = Object.assign(new Error('Unsatisfied constraints'), { name: 'OverconstrainedError' })

    expect(voiceJoinErrorMessage(error)).toBe(
      'Выбранный микрофон не поддерживает необходимые настройки. Выберите другое устройство или подключитесь без микрофона.',
    )
  })

  it('preserves other connection failures and provides a fallback for non-error causes', () => {
    expect(voiceJoinErrorMessage(new Error('Превышено время ожидания голосового подключения.')))
      .toBe('Превышено время ожидания голосового подключения.')
    expect(voiceJoinErrorMessage('unknown')).toBe('Не удалось подключиться к голосовому каналу.')
  })
})
