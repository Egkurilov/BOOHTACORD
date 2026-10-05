import { test, type Page } from '@playwright/test'

/** Bound fixture RPCs so cleanup cannot hide the original hanging operation. */
export async function inputGate(page: Page, method: string, args: unknown[] = [], timeout = 20000) {
  const log = (state: string) => {
    if (method !== 'read' && method !== 'sample') {
      console.log(JSON.stringify({ gate: 'audio-input-lifecycle', stage: method, state }))
    }
  }
  log('begin')
  try {
    return await test.step(`audio input: ${method}`, () => page.evaluate(({ method, args }) => {
      const gate = (window as any).audioInputGate
      if (method === 'stop' && !gate) return
      return gate[method](...args)
    }, { method, args }), { timeout })
  } finally {
    log('end')
  }
}

export async function inputReady(page: Page) {
  await test.step('audio input: fixture ready', () => page.waitForFunction(
    () => typeof (window as any).audioInputGate?.mount === 'function', undefined, { timeout: 20000 },
  ), { timeout: 22000 })
}

export async function closeInput(page: Page) {
  if (!page.isClosed()) await inputGate(page, 'stop', [], 5000).catch(() => {})
}
