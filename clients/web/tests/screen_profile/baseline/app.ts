import { ScreenBaselineSession } from './session'

const session = new ScreenBaselineSession()
;(window as any).screenBaseline = session

function element<T extends HTMLElement>(selector: string) {
  const found = document.querySelector<T>(selector)
  if (!found) throw new Error(`Missing baseline control: ${selector}`)
  return found
}

element<HTMLButtonElement>('#connect').onclick = () => {
  const token = element<HTMLInputElement>('#token').value
  session.configure({
    url: element<HTMLInputElement>('#url').value,
    token,
    role: element<HTMLSelectElement>('#role').value as 'publisher' | 'viewer',
  })
  element<HTMLInputElement>('#token').value = ''
  void session.connect().catch(() => undefined)
}
element<HTMLButtonElement>('#synthetic').onclick = () => void session.startSynthetic().catch(() => undefined)
element<HTMLButtonElement>('#display').onclick = () => void session.startDisplayCapture().catch(() => undefined)
element<HTMLButtonElement>('#stop').onclick = () => void session.stop()
element<HTMLButtonElement>('#report').onclick = async () => {
  const status = element<HTMLElement>('#status')
  status.textContent = 'warmup-5s'
  await new Promise(resolve => setTimeout(resolve, 5000))
  status.textContent = 'sampling-10s'
  const report = {
    schemaVersion: 1,
    sourceRevision: 'record-separately',
    sfuImageDigest: 'record-separately',
    warmupSeconds: 5,
    sampleWindowSeconds: 10,
    sampleIntervalSeconds: 1,
    samples: await session.collectSamples(10000, 1000),
  }
  const link = document.createElement('a')
  link.href = URL.createObjectURL(new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' }))
  link.download = 'screen-share-baseline-numeric.json'
  link.click()
  URL.revokeObjectURL(link.href)
}
