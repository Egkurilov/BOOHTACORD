import { readFile, stat } from 'node:fs/promises'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const configuredOrigin = process.env.VITE_PUBLIC_ORIGIN
if (!configuredOrigin) throw new Error('VITE_PUBLIC_ORIGIN is required to verify a production build')
const origin = new URL(configuredOrigin)
if (origin.protocol !== 'https:' || origin.origin !== configuredOrigin.replace(/\/$/, '')) {
  throw new Error('VITE_PUBLIC_ORIGIN must be an HTTPS origin without a path')
}
const html = await readFile(resolve(root, 'dist/index.html'), 'utf8')
const content = (key, value) => {
  const tag = html.match(new RegExp('<meta\\b(?=[^>]*' + key + '="' + value + '")[^>]*>'))?.[0]
  const match = tag?.match(/content="([^"]*)"/)
  if (!match?.[1]) throw new Error('Missing or empty ' + key + '=' + value)
  return match[1]
}
const description = 'Присоединяйтесь к BOOHTACORD: общайтесь в чатах, заходите в голосовые каналы и делитесь экраном с участниками своей гильдии.'
const title = 'BOOHTACORD — голос и чаты вашей гильдии'
const image = origin.origin + '/social/boohtacord-og-1200x630.png'
const expected = new Map([
  ['name|description', description], ['property|og:type', 'website'],
  ['property|og:site_name', 'BOOHTACORD'], ['property|og:title', title],
  ['property|og:description', description], ['property|og:url', origin.origin + '/'],
  ['property|og:locale', 'ru_RU'], ['property|og:image', image],
  ['property|og:image:width', '1200'], ['property|og:image:height', '630'],
  ['property|og:image:type', 'image/png'],
  ['property|og:image:alt', 'BOOHTACORD — голос, чаты и демонстрация экрана для вашей гильдии'],
  ['name|twitter:card', 'summary_large_image'], ['name|twitter:title', title],
  ['name|twitter:description', description], ['name|twitter:image', image],
  ['name|twitter:image:alt', 'BOOHTACORD — голос, чаты и демонстрация экрана для вашей гильдии'],
  ['name|theme-color', '#10102A'],
])
for (const [key, value] of expected) {
  const [attribute, name] = key.split('|')
  if (content(attribute, name) !== value) throw new Error('Unexpected ' + key + ' value')
}
if (!html.includes('href="' + origin.origin + '/"')) throw new Error('Canonical URL is not absolute')
const scriptIndex = html.indexOf('<script')
if (html.includes('__SOCIAL_ORIGIN__') || (scriptIndex >= 0 && html.lastIndexOf('<meta') > scriptIndex)) {
  throw new Error('Unresolved social origin or metadata after the application script')
}
const pngPath = resolve(root, 'dist/social/boohtacord-og-1200x630.png')
const png = await readFile(pngPath)
const size = await stat(pngPath)
if (png.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error('Social image is not a PNG')
if (png.readUInt32BE(16) !== 1200 || png.readUInt32BE(20) !== 630) throw new Error('Social image must be 1200x630')
if (size.size > 512 * 1024) throw new Error('Social image exceeds 512 KiB')
console.log('Social preview verified: ' + image + '; ' + size.size + ' bytes; 1200x630')
