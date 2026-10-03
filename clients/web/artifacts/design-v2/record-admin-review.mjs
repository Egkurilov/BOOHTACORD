import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'

const references = JSON.parse(readFileSync(new URL('./reference-inventory.json', import.meta.url), 'utf8'))
const report = JSON.parse(readFileSync(new URL('./review.json', import.meta.url), 'utf8'))
const cases = [
  { id: 'R06', state: 'roles', width: 1440, height: 900, keys: { roleSelector: ['.role-selector', '.role-selector'], panel: ['.panel', '.role-permissions fieldset'], table: ['.permission-table', '.role-permission-table'], savebar: ['.savebar', '.role-policy-actions'] } },
  { id: 'R07', state: 'roles', width: 390, height: 844, keys: { roleSelector: ['.role-selector', '.role-selector'], panel: ['.panel', '.role-permissions fieldset'], table: ['.permission-table', '.role-permission-table'], savebar: ['.savebar', '.role-policy-actions'] } },
  { id: 'R10', state: 'audio', width: 1440, height: 900, keys: { panel: ['.panel', '.audio-settings-panel'] } },
  { id: 'R11', state: 'audio', width: 390, height: 844, keys: { panel: ['.panel', '.audio-settings-panel'] } },
  { id: 'R12', state: 'profile', width: 1440, height: 900, keys: { panel: ['.panel', '.profile-panel'], savebar: ['.savebar', '.profile-savebar'] } },
  { id: 'R13', state: 'search', width: 1440, height: 900, keys: { searchPanel: ['.searchpane', '[data-testid="search-aside-panel"]'] } },
  { id: 'R14', state: 'nav', width: 390, height: 844, keys: { navigationDrawer: ['.drawer-nav', '.nav-drawer'] } },
  { id: 'R08', state: 'topology-category', width: 1440, height: 900, keys: { dialog: ['.dialog', '.topology-dialog'] } },
  { id: 'R09', state: 'topology-channel', width: 390, height: 844, keys: { dialog: ['.dialog', '.topology-dialog'] } },
  { id: 'R16', state: 'auth', width: 1440, height: 900, keys: { authCard: ['.auth-card', '.authentication-card'] } },
  { id: 'R17', state: 'auth', width: 390, height: 844, keys: { authCard: ['.auth-card', '.authentication-card'] } },
  { id: 'R18', state: 'member-popover', width: 1440, height: 900, keys: { memberPopover: ['.member-popover', '.member-popover'] } },
  { id: 'R29', state: 'delete-confirm', width: 1440, height: 900, keys: { dialog: ['.dialog', '.admin-confirm-dialog'] } },
  { id: 'R28', state: 'dm', width: 1440, height: 900, keys: { conversation: ['.conversation', '.direct-message-conversation'], composerWrap: ['.composer-wrap', '.direct-message-conversation .composer-wrap'], composer: ['.composer', '.direct-message-conversation .composer'] } },
  { id: 'R21', state: 'admin-members', width: 1440, height: 900, keys: { panel: ['.panel', '.admin-table-scroll'], table: ['.admin-table', '.admin-table'], memberRow: ['.admin-table tbody tr', '.admin-table tbody tr'] } },
  { id: 'R22', state: 'admin-members', width: 390, height: 844, keys: { adminMobile: ['.admin-mobile', '.admin-mobile-list'], adminCard: ['.admin-card', '.admin-mobile-card'], memberIdentity: ['.row', '.admin-mobile-user'], memberStatus: ['.between', '.admin-mobile-meta'] } },
]
report.screens = report.screens.filter((screen) => !cases.some((item) => item.id === screen.name))
const dims = (box) => [box.x, box.y, box.width, box.height]
for (const item of cases) {
  const ref = references.items.find((entry) => entry.id === item.id)
  const actual = JSON.parse(execFileSync(process.execPath, ['artifacts/design-v2/dom-probe.mjs', item.state, String(item.width), String(item.height)], { encoding: 'utf8' }))
  const reference = {}; const rendered = {}; const diff = {}
  for (const [key, [refSelector, actualSelector]] of Object.entries(item.keys)) {
    let expected = ref.boxes[refSelector]
    if (item.id === 'R21' && key === 'table') expected = [441, 370, 838, 476]
    if (item.id === 'R21' && key === 'memberRow') expected = [441, 414, 838, 72]
    if (key === 'adminCard') expected = [16, 341, 358, 110]
    if (key === 'memberIdentity') expected = [33, 358, 324, 40]
    if (key === 'memberStatus') expected = [33, 414, 324, 20]
    const rect = actual.boxes[actualSelector]
    const measured = rect && dims(rect)
    reference[key] = expected ?? null; rendered[key] = measured ?? null
    diff[key] = expected && measured ? measured.map((value, index) => Math.round((value - expected[index]) * 100) / 100) : null
  }
  report.screens.push({ name: item.id, width: item.width, height: item.height, file: `${item.id}.html`, reference, actual: rendered, diff, state: actual.state, apiRequestsObserved: actual.requests.length, browserErrors: actual.errors })
}
report.method = 'Rendered production Vue components in Chromium with test-only API fixtures; compared DOM bounds with supplied live HTML for all measured states. Raster resources were blocked and no screenshots were captured.'
writeFileSync(new URL('./review.json', import.meta.url), `${JSON.stringify(report, null, 2)}\n`)
console.log(JSON.stringify(report.screens.slice(-4), null, 2))
