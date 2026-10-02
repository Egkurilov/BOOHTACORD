import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { publishGitHubRelease } from './publish_release.mjs'

export { publishGitHubRelease } from './publish_release.mjs'

function parseArgs(args) {
  const parsed = { assets: [] }
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index]
    if (argument === '--tag') parsed.tag = args[++index]
    else if (argument === '--asset') parsed.assets.push(args[++index])
    else throw new Error(`Unknown argument: ${argument}`)
  }
  return parsed
}

async function main() {
  const { tag, assets } = parseArgs(process.argv.slice(2))
  const [owner, repo] = (process.env.GITHUB_REPOSITORY ?? '').split('/')
  if (!owner || !repo) throw new Error('GITHUB_REPOSITORY is missing or invalid')
  const version = tag?.replace(/^android-v/, '')
  if (!version) throw new Error('Release tag is missing')

  const body = [
    'Signed Android APKs for version ' + version + '.',
    '',
    'Voice and screen sharing updates:',
    '- Live voice roster and clearer connection/reconnect status.',
    '- More reliable audio-device refresh and system-output fallback.',
    '- Fixed Android direct-buffer handling used while generating participant-card screen-share thumbnails.',
    '- Screen-share diagnostics distinguish decoded and rendered FPS and report bounded sender/receiver metrics.',
    '- Quality and FPS changes during an active stream; viewer recovery when a share restarts.',
    '- Android keyboard Send action works in text channels and direct messages.',
    '- App version and build number are visible before login and in profile settings.',
    '',
    'Download exactly one APK matching your device:',
    '- arm64-v8a: most modern Android phones and tablets',
    '- armeabi-v7a: older 32-bit ARM devices',
    '- x86_64: Android emulators and x86-64 devices',
  ].join('\n')

  const { release, uploaded } = await publishGitHubRelease({
    tag,
    title: `BOOHTACORD Android ${version}`,
    body,
    assets,
    token: process.env.GITHUB_TOKEN,
    owner,
    repo,
  })

  for (const asset of uploaded) {
    console.log(`${asset.alreadyPresent ? 'Verified existing' : 'Uploaded'} ${asset.name} (${asset.size} bytes)`)
  }
  console.log(
    `GitHub release: ${release.html_url ?? `https://github.com/${owner}/${repo}/releases/tag/${tag}`}`,
  )
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(error.message)
    process.exitCode = 1
  })
}
