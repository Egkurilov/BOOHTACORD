import assert from 'node:assert/strict'
import test from 'node:test'
import { publishGitHubRelease } from './publish.mjs'
import { apiRoot, releasePath, release, json, withAsset } from './test_helpers.mjs'

test('skips an identical asset when a tag-triggered job is safely retried', async () => {
  await withAsset(Buffer.from('already-published'), async (asset) => {
    const calls = []
    const fetchImpl = async (url, init = {}) => {
      calls.push({ url: String(url), method: init.method ?? 'GET' })
      const parsed = new URL(url)
      if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) {
        return json(release)
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets`) {
        return json([{ id: 91, name: asset.name, size: asset.size, digest: asset.digest }])
      }
      assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
    }

    const result = await publishGitHubRelease({
      tag: 'android-v1.0.15',
      title: 'BOOHTACORD Android 1.0.15',
      body: 'Android release notes',
      assets: [asset.path],
      token: 'write-token',
      apiRoot,
      fetchImpl,
      sleep: async () => {},
    })

    assert.equal(result.uploaded.length, 1)
    assert.equal(result.uploaded[0].alreadyPresent, true)
    assert.equal(calls.some((call) => call.method === 'POST'), false)
  })
})

test('retries a transient upload error when the API confirms the asset was not created', async () => {
  await withAsset(Buffer.from('retry-artifact'), async (asset) => {
    let uploadCalls = 0
    let assetLists = 0
    const delays = []
    const fetchImpl = async (url, init = {}) => {
      const parsed = new URL(url)
      if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) {
        return json(release)
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
        assetLists += 1
        return json([])
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'POST') {
        uploadCalls += 1
        if (uploadCalls === 1) return json({ message: 'temporarily unavailable' }, 503)
        return json({ id: 92, name: asset.name, size: asset.size, digest: asset.digest }, 201)
      }
      assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
    }

    const result = await publishGitHubRelease({
      tag: 'android-v1.0.15',
      title: 'BOOHTACORD Android 1.0.15',
      body: 'Android release notes',
      assets: [asset.path],
      token: 'write-token',
      apiRoot,
      fetchImpl,
      sleep: async (milliseconds) => delays.push(milliseconds),
    })

    assert.equal(uploadCalls, 2)
    assert.equal(assetLists, 2)
    assert.deepEqual(delays, [1_000])
    assert.equal(result.uploaded[0].alreadyPresent, false)
  })
})
