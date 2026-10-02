import { describe, expect, it } from 'vitest'

import { formatMessage } from './message_format'

describe('message formatting', () => {
  it('creates typed formatting blocks without treating content as HTML', () => {
    expect(formatMessage('**жирный** и *курсив* с `кодом`\n\n```<script>bad()</script>```')).toEqual([
      { kind: 'PARAGRAPH', spans: [{ kind: 'BOLD', value: 'жирный' }, { kind: 'TEXT', value: ' и ' }, { kind: 'ITALIC', value: 'курсив' }, { kind: 'TEXT', value: ' с ' }, { kind: 'CODE', value: 'кодом' }] },
      { kind: 'CODE_BLOCK', value: '<script>bad()</script>' },
    ])
  })

  it('permits only explicit http and https links', () => {
    const [block] = formatMessage('[документация](https://example.test/docs) [опасно](javascript:alert(1))')
    expect(block).toEqual({ kind: 'PARAGRAPH', spans: [
      { kind: 'LINK', value: 'документация', href: 'https://example.test/docs' },
      { kind: 'TEXT', value: ' [опасно](javascript:alert(1))' },
    ] })
  })
})
