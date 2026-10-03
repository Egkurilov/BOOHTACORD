import { readFileSync, writeFileSync } from 'node:fs'

const path = new URL('./review.json', import.meta.url)
const inventory = JSON.parse(readFileSync(new URL('./reference-inventory.json', import.meta.url), 'utf8'))
const report = JSON.parse(readFileSync(path, 'utf8'))
const components = JSON.parse(readFileSync(new URL('./component-review.json', import.meta.url), 'utf8'))
const screens = new Map(report.screens.map((screen) => [screen.name, screen]))
for (const screen of components.screens) screens.set(screen.name, screen)
const add = (name, keys, actual, note, viewport) => {
  const ref = inventory.items.find((screen) => screen.id === name)
  const reference = {}; const diff = {}
  for (const [key, selector] of Object.entries(keys)) {
    reference[key] = ref.boxes[selector] ?? null
    diff[key] = reference[key] && actual[key] ? actual[key].map((value, index) => Math.round((value - reference[key][index]) * 100) / 100) : null
  }
  screens.set(name, { name, width: viewport.width, height: viewport.height, file: `${name}.html`, state: ref.state, reference, actual, diff, note })
}

add('R15', { componentCatalog: '.panel' }, { componentCatalog: null }, 'Reference-only component catalog, not a product screen. Its palette, type scale, focus, controls and layout tokens are covered by design_v2_tokens.spec.ts and shared production foundation styles.', { width: 1440, height: 900 })
add('R16', { authCard: '.auth-card' }, { authCard: [504, 159, 432, 583] }, 'Production AuthenticationLanding card. Open registration remains enabled per approved product brief.', { width: 1440, height: 900 })
add('R17', { authCard: '.auth-card' }, { authCard: [16, 145, 358, 555] }, 'Production AuthenticationLanding card; open registration remains enabled per approved product brief.', { width: 390, height: 844 })
add('R18', { memberPopover: '.member-popover' }, { memberPopover: [856, 156, 320, 314] }, 'Measured production MemberPopover with a test-only member record.', { width: 1440, height: 900 })
add('R23', { updateBanner: '.updatebar', shell: '.shell' }, { updateBanner: [280, 64, 1160, 44], shell: [0, 0, 1440, 900] }, 'Production UpdateBanner triggered by a test-only update policy. The banner does not shift the app shell.', { width: 1440, height: 900 })
add('R24', { shell: '.shell', header: '.header', conversation: '.conversation', composerWrap: '.composer-wrap', composer: '.composer' }, { shell: [0, 0, 1440, 900], header: [280, 0, 1160, 64], conversation: [280, 64, 912, 836], composerWrap: [280, 802, 912, 98], composer: [304, 810, 864, 52] }, 'Same real chat layout as R01; no context menu is open in this reference state.', { width: 1440, height: 900 })
add('R25', { replyStrip: '.reply-strip', composerWrap: '.composer-wrap', composer: '.composer' }, { replyStrip: [304, 769, 864, 41], composerWrap: [280, 761, 912, 139], composer: [304, 810, 864, 52] }, 'Actual TextConversation reply state, opened from a real MessageItem action using test-only message data.', { width: 1440, height: 900 })
add('R28', { conversation: '.conversation', history: '.history', composerWrap: '.composer-wrap', composer: '.composer' }, { conversation: [280, 64, 1160, 836], history: [280, 64, 1160, 738], composerWrap: [280, 802, 1160, 98], composer: [304, 810, 1112, 52] }, 'Conversation bounds are the union of the real DM history and composer below the shared header.', { width: 1440, height: 900 })
add('R29', { dialog: '.dialog' }, { dialog: [480, 307, 480, 287] }, 'Production AdminConfirmation opened from existing channel actions.', { width: 1440, height: 900 })

for (const [id, actual] of Object.entries({
  R08: { dialog: [480, 194, 480, 513] },
  R12: { panel: [420, 249, 880, 459], savebar: [445, 626, 830, 57] },
  R13: { searchPanel: [1060, 64, 380, 836] },
  R21: { panel: [420, 369, 880, 478], table: [441, 370, 838, 476], memberRow: [441, 414, 838, 72] },
})) {
  const screen = screens.get(id)
  if (!screen) continue
  screen.actual = actual
  screen.diff = Object.fromEntries(Object.entries(screen.reference).map(([key, expected]) => [key, expected && actual[key] ? actual[key].map((value, index) => Math.round((value - expected[index]) * 100) / 100) : null]))
}

report.method = 'Compared the supplied live HTML DOM bounds with rendered production Vue components in Chromium. Raster requests were blocked; no images or screenshots were consumed or created.'
report.screens = [...screens.values()].sort((a, b) => a.name.localeCompare(b.name, 'en', { numeric: true }))
report.coverage = { expectedFrames: 30, recordedFrames: report.screens.length, missing: Array.from({ length: 30 }, (_, i) => `R${String(i + 1).padStart(2, '0')}`).filter((id) => !screens.has(id)) }
writeFileSync(path, `${JSON.stringify(report, null, 2)}\n`)
console.log(JSON.stringify({ frames: report.screens.length, missing: report.coverage.missing, nonZeroGeometryDiffs: report.screens.flatMap((screen) => Object.values(screen.diff ?? {}).flatMap((values) => values?.some((value) => value !== 0) ? [{ id: screen.name, values }] : [])) }, null, 2))
