import { readFile, stat } from 'node:fs/promises'
import path from 'node:path'
import { apiUrl, isRetryable, maxAttempts, retryDelay, sendJson } from './github_api.mjs'

export async function uploadAssets({ release, assets, token, owner, repo, apiRoot, fetchImpl, sleep }) {
  const repositoryPath = `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}`
  const assetsUrl = apiUrl(
    apiRoot,
    `${repositoryPath}/releases/${encodeURIComponent(release.id)}/assets`,
  )

  async function listAssets() {
    const url = `${assetsUrl}?per_page=50&page=1`
    const result = await sendJson({ fetchImpl, token, url })
    if (!Array.isArray(result)) throw new Error('GitHub returned an invalid asset list')
    return result
  }

  const uploaded = []
  for (const assetPath of assets) {
    const name = path.basename(assetPath)
    if (!/^[A-Za-z0-9_.-]{1,255}$/.test(name)) {
      throw new Error(`Invalid release asset name: ${name}`)
    }
    const size = (await stat(assetPath)).size
    if (size === 0 || size > 95_000_000) {
      throw new Error(`Release asset is empty or exceeds the 95 MB limit: ${name}`)
    }

    const currentAssets = await listAssets()
    const current = currentAssets.find((asset) => asset.name === name)
    if (current) {
      if (current.size !== size) {
        throw new Error(`GitHub has a conflicting existing asset: ${name}`)
      }
      uploaded.push({ name, size, alreadyPresent: true })
      continue
    }

    const bytes = await readFile(assetPath)
    let completed = false
    for (let attempt = 1; attempt <= maxAttempts && !completed; attempt += 1) {
      try {
        const uploadUrl = release.upload_url.replace(/\{.*$/, '')
        const url = `${uploadUrl}?name=${encodeURIComponent(name)}`
        await sendJson({ fetchImpl, token, url, method: 'POST', body: bytes })
        completed = true
      } catch (error) {
        // A completed upload whose response was lost must not be blindly retried.
        try {
          const afterFailure = await listAssets()
          const accepted = afterFailure.find((asset) => asset.name === name)
          if (accepted) {
            if (accepted.size !== size) {
              throw new Error(`GitHub has a conflicting existing asset: ${name}`)
            }
            completed = true
          }
        } catch (confirmationError) {
          if (confirmationError.message.startsWith('GitHub has a conflicting existing asset:')) {
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

  return uploaded
}
