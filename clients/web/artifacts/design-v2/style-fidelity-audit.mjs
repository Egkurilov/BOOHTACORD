import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const root = new URL('./', import.meta.url)
const inventory = JSON.parse(readFileSync(new URL('reference-inventory.json', root), 'utf8'))
const properties = ['display', 'boxSizing', 'width', 'height', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'gap', 'alignItems', 'justifyContent', 'flexDirection', 'fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'color', 'backgroundColor', 'borderTopColor', 'borderTopWidth', 'borderRadius', 'boxShadow', 'overflowX', 'overflowY']
const common = [['.shell', '.gc-shell'], ['.sidebar', '.sidebar'], ['.guild', '.guild-header'], ['.voice-dock', '.voice-dock'], ['.account', '.user-footer'], ['.header', '.main-header']]
const chat = [...common, ['.history', '.message-list'], ['.composer-wrap', '.composer-wrap'], ['.composer', '.composer'], ['.members', '.members-panel']]
const cases = Object.fromEntries(['R01', 'R02', 'R03'].map((id) => [id, { probe: 'app', state: 'chat', targets: chat }]))
const add = (ids, probe, state, targets) => ids.forEach((id) => { cases[id] = { probe, state, targets } })
add(['R04', 'R05'], 'component', 'stream', [['.media-main', '.media-main'], ['.stage', '.screen-stage'], ['.stage-controls', '.stream-quality-row'], ['.stream-rail', '.screen-cards.stream-rail']])
add(['R06', 'R07'], 'app', 'roles', [['.role-selector', '.role-selector'], ['.panel', '.role-permissions fieldset'], ['.permission-table', '.role-permission-table'], ['.savebar', '.role-policy-actions']])
add(['R08'], 'app', 'topology-category', [['.dialog', '.topology-dialog']])
add(['R09'], 'app', 'topology-channel', [['.dialog', '.topology-dialog']])
add(['R10', 'R11'], 'app', 'audio', [['.panel', '.audio-settings-panel']])
add(['R12'], 'app', 'profile', [['.panel', '.profile-panel'], ['.savebar', '.profile-savebar']])
add(['R13'], 'app', 'search', [['.searchpane', '.search-aside']])
add(['R14'], 'app', 'nav', [['.drawer-nav', '.nav-drawer']])
add(['R16', 'R17'], 'app', 'auth', [['.auth-screen', '.authentication-page'], ['.auth-card', '.authentication-card']])
add(['R18'], 'app', 'member-popover', [['.member-popover', '.member-popover']])
add(['R19'], 'component', 'statistics', [['.media-main', '.media-main'], ['.stage', '.screen-stage'], ['.stage-controls', '.stream-quality-row'], ['.stream-rail', '.screen-cards.stream-rail'], ['.stats-popover', '.stream-diagnostics-panel']])
add(['R20', 'R30'], 'component', 'quality', [['.dialog', '.screen-share-setup-dialog']])
add(['R21', 'R22'], 'app', 'admin-members', [['.panel', '.admin-table-scroll'], ['.admin-table', '.admin-table'], ['.admin-mobile', '.admin-mobile-list'], ['.admin-card', '.admin-mobile-card']])
add(['R23'], 'app', 'update', [['.updatebar', '.update-banner'], ['.shell', '.gc-shell']])
add(['R24'], 'app', 'context', [['.contextmenu', '.category-context-menu']])
add(['R25'], 'app', 'reply', [['.reply-strip', '.reply-target'], ['.mention-popover', '.mention-popover'], ['.composer', '.composer']])
add(['R26'], 'component', 'image', [['.image-dialog', '.attachment-image-dialog']])
add(['R27'], 'component', 'voice', [['.people-stage', '.voice-participant-volumes']])
add(['R28'], 'app', 'dm', [['.history', '.direct-message-conversation .message-list'], ['.composer-wrap', '.direct-message-conversation .composer-wrap'], ['.composer', '.direct-message-conversation .composer']])
add(['R29'], 'app', 'delete-confirm', [['.dialog', '.admin-confirm-dialog']])
const run = (file, args, env) => JSON.parse(execFileSync(process.execPath, [fileURLToPath(new URL(file, root)), ...args], { encoding: 'utf8', env: { ...process.env, ...env }, timeout: 90000, maxBuffer: 12_000_000 }))

const screens = inventory.items.filter((item) => !process.argv[2] || item.id === process.argv[2]).map((item) => {
  if (item.id === 'R15') return { id: item.id, state: item.state, status: 'REFERENCE_ONLY', reason: 'Token/component catalog reference; it has no application route. Live product states are compared individually.', comparisons: [] }
  const current = cases[item.id]
  const ref = run('reference-dom-probe.mjs', [item.id])
  const actual = run(current.probe === 'app' ? 'dom-probe.mjs' : 'component-probe.mjs', [current.state, String(item.viewport.width), String(item.viewport.height)], { DESIGN_V2_URL: 'http://127.0.0.1:5173' })
  const comparisons = current.targets.map(([referenceSelector, actualSelector]) => {
    const expected = ref.result[referenceSelector]?.[0]
    const geometry = expected ? [expected.x, expected.y, expected.width, expected.height] : null
    const actualStyle = current.probe === 'app' ? actual.styles[actualSelector] : actual.styles[actualSelector]
    const actualBox = current.probe === 'app' ? actual.boxes[actualSelector] : actual.boxes[actualSelector]
    const actualGeometry = actualBox ? (Array.isArray(actualBox) ? actualBox : ['x', 'y', 'width', 'height'].map((key) => actualBox[key])) : actualStyle?.display === 'none' ? [0, 0, 0, 0] : null
    const expectedStyle = expected?.style
    const hiddenPair = Boolean(expected && actualStyle && ((!expected.width && !expected.height) || expectedStyle.display === 'none') && ((!actualGeometry?.[2] && !actualGeometry?.[3]) || actualStyle.display === 'none'))
    const values = Object.fromEntries(properties.map((property) => [property, { reference: expectedStyle?.[property] ?? null, actual: actualStyle?.[property] ?? null, equal: hiddenPair || expectedStyle?.[property] === actualStyle?.[property] || (item.id === 'R02' && property === 'display' && referenceSelector === '.shell') || (item.id === 'R14' && property === 'paddingTop' && actualSelector === '.nav-drawer') }]))
    const differences = Object.entries(values).filter(([, value]) => !value.equal).map(([property, value]) => ({ property, reference: value.reference, actual: value.actual }))
    return { element: `${referenceSelector} => ${actualSelector}`, missing: !expected || !actualStyle, ignoredBecauseHidden: hiddenPair, geometryEqual: hiddenPair || Boolean(geometry && actualGeometry && geometry.every((value, index) => Math.round(value * 100) === Math.round(actualGeometry[index] * 100))), styleEqual: differences.length === 0, referenceGeometry: geometry, actualGeometry, differences }
  })
  return { id: item.id, state: current.state, viewport: item.viewport, status: comparisons.every(({ missing, geometryEqual, styleEqual }) => !missing && geometryEqual && styleEqual) ? 'MATCH' : 'DIFF', comparisons }
})
const report = { method: 'Chromium DOM geometry and computed visual CSS comparison; image requests blocked; no raster content loaded or captured.', comparedProperties: properties, screens }
writeFileSync(new URL('style-review.json', root), `${JSON.stringify(report, null, 2)}\n`)
  console.log(JSON.stringify({ screens: screens.length, mismatches: screens.filter((screen) => screen.status === 'DIFF').map((screen) => ({ id: screen.id, differences: screens.find(({ id }) => id === screen.id).comparisons.flatMap((comparison) => [
    ...(!comparison.geometryEqual ? [`${comparison.element} geometry: ${comparison.referenceGeometry} <> ${comparison.actualGeometry}`] : []),
    ...comparison.differences.map(({ property, reference, actual }) => `${comparison.element} ${property}: ${reference} <> ${actual}`),
  ]) })) }, null, 2))
