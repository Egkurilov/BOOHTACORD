import { readFile, stat } from 'node:fs/promises'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const defaultApiRoot = 'https://api.gitverse.ru'
const accept = 'application/vnd.gitverse.object+json;version=1'
const assetCeilingBytes = 95_000_000
const requestTimeoutMs = 15 * 60 * 1000
const maxAttempts = 3

class GitVerseApiError extends Error {
  constructor(status, method, url) {
    super(`GitVerse API ${method} failed with HTTP ${status}`)
    this.name = 'GitVerseApiError'
    this.status = status
    this.url = url
  }
}

function isRetryable(error) {
  return !(error instanceof GitVerseApiError) ||
    [408, 425, 429].includes(error.status) ||
    error.status >= 500
}

function retryDelay(attempt) {
  return Math.min(1_000 * (2 ** (attempt - 1)), 8_000)
}

function apiUrl(apiRoot, pathname) {
  return `${apiRoot.replace(/\/$/, '')}${pathname}`
}

async function sendJson({ fetchImpl, token, url, method = 'GET', body }) {
  const isMultipart = typeof FormData !== 'undefined' && body instanceof FormData
  const response = await fetchImpl(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: accept,
      ...(body == null || isMultipart ? {} : { 'Content-Type': 'application/json' }),
    },
    ...(body == null ? {} : { body: isMultipart ? body : JSON.stringify(body) }),
    signal: AbortSignal.timeout(requestTimeoutMs),
  })

  if (!response.ok) throw new GitVerseApiError(response.status, method, url)
  if (response.status === 204) return null
  return response.json()
}

export async function publishGitVerseRelease({
  tag,
  title,
  body,
  assets,
  token,
  owner = 'egkurilov',
  repo = 'BOOHTACORD',
  apiRoot = defaultApiRoot,
  fetchImpl = fetch,
  sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
}) {
  if (!token) throw new Error('RELEASE_API_KEY is required')
  if (!/^android-v\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$/.test(tag ?? '')) {
    throw new Error('Release tag must use the android-vX.Y.Z form')
  }
  if (!Array.isArray(assets) || assets.length === 0) {
    throw new Error('At least one APK asset is required')
  }

  const repositoryPath = `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}`
  const releaseCollectionUrl = apiUrl(apiRoot, `${repositoryPath}/releases`)
  const tagReleaseUrl = apiUrl(
    apiRoot,
    `${repositoryPath}/releases/tags/${encodeURIComponent(tag)}`,
  )

  async function findRelease() {
    try {
      return await sendJson({ fetchImpl, token, url: tagReleaseUrl })
    } catch (error) {
      if (error instanceof GitVerseApiError && error.status === 404) return null
      throw error
    }
  }

  let release = null
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    release = await findRelease()
    if (release) break

    try {
      release = await sendJson({
        fetchImpl,
        token,
        url: releaseCollectionUrl,
        method: 'POST',
        body: {
          tag_name: tag,
          name: title,
          target_commitish: 'master',
          body,
          draft: false,
          prerelease: false,
          is_authorized_only: false,
        },
      })
      break
    } catch (error) {
      // A lost response or 409 may mean the release was created successfully.
      try {
        release = await findRelease()
      } catch (_) {
        // Keep the original create error; never include a token or response body.
      }
      if (release) break
      if (!isRetryable(error) || attempt === maxAttempts) throw error
      await sleep(retryDelay(attempt))
    }
  }
  if (!release?.id) throw new Error(`GitVerse did not return release metadata for ${tag}`)
  if (release.tag_name && release.tag_name !== tag) {
    throw new Error('GitVerse returned a release for a different tag')
  }

  const assetsUrl = apiUrl(
    apiRoot,
    `${repositoryPath}/releases/${encodeURIComponent(release.id)}/assets`,
  )

  async function listAssets() {
    const url = `${assetsUrl}?per_page=50&page=1`
    const result = await sendJson({ fetchImpl, token, url })
    if (!Array.isArray(result)) throw new Error('GitVerse returned an invalid asset list')
    return result
  }

  const uploaded = []
  for (const assetPath of assets) {
    const name = path.basename(assetPath)
    if (!/^[A-Za-z0-9_.-]{1,255}$/.test(name)) {
      throw new Error(`Invalid release asset name: ${name}`)
    }
    const size = (await stat(assetPath)).size
    if (size === 0 || size > assetCeilingBytes) {
      throw new Error(`Release asset is empty or exceeds the 95 MB limit: ${name}`)
    }

    const currentAssets = await listAssets()
    const current = currentAssets.find((asset) => asset.name === name)
    if (current) {
      if (current.size !== size) {
        throw new Error(`GitVerse has a conflicting existing asset: ${name}`)
      }
      uploaded.push({ name, size, alreadyPresent: true })
      continue
    }

    const bytes = await readFile(assetPath)
    let completed = false
    for (let attempt = 1; attempt <= maxAttempts && !completed; attempt += 1) {
      try {
        const form = new FormData()
        form.append('attachment', new Blob([bytes]), name)
        const url = `${assetsUrl}?name=${encodeURIComponent(name)}`
        await sendJson({ fetchImpl, token, url, method: 'POST', body: form })
        completed = true
      } catch (error) {
        // A completed upload whose response was lost must not be blindly retried.
        try {
          const afterFailure = await listAssets()
          const accepted = afterFailure.find((asset) => asset.name === name)
          if (accepted) {
            if (accepted.size !== size) {
              throw new Error(`GitVerse has a conflicting existing asset: ${name}`)
            }
            completed = true
          }
        } catch (confirmationError) {
          if (confirmationError.message.startsWith('GitVerse has a conflicting existing asset:')) {
            throw confirmationError
          }
        }
        if (completed) break
        if (!isRetryable(error) || attempt === maxAttempts) throw error
        await sleep(retryDelay(attempt))
      }
    }
    uploaded.push({ name, size, alreadyPresent: false })
  }

  return { release, uploaded }
}

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

  const { release, uploaded } = await publishGitVerseRelease({
    tag,
    title: `BOOHTACORD Android ${version}`,
    body,
    assets,
    token: process.env.RELEASE_API_KEY,
    owner,
    repo,
  })

  for (const asset of uploaded) {
    console.log(`${asset.alreadyPresent ? 'Verified existing' : 'Uploaded'} ${asset.name} (${asset.size} bytes)`)
  }
  console.log(
    `GitVerse release: ${release.html_url ?? `https://gitverse.ru/${owner}/${repo}/releases/tag/${tag}`}`,
  )
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(error.message)
    process.exitCode = 1
  })
}
