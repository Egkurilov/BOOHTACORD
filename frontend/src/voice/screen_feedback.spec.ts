import { describe, expect, it } from 'vitest'

import { screenFailureMessage } from './screen_feedback'

describe('screen feedback', () => {
  it.each([
    ['AbortError', 'Выбор источника отменён'],
    ['NotAllowedError', 'Браузер запретил захват экрана'],
    ['NotReadableError', 'Источник недоступен для захвата'],
  ])('keeps %s distinct', (name, message) => {
    expect(screenFailureMessage(Object.assign(new Error(), { name }))).toContain(message)
  })
})
