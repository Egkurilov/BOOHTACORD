import assert from 'node:assert/strict'
import test from 'node:test'
import { publishGitHubRelease } from './publish.mjs'
import { apiRoot, releasePath, release, json, withAsset } from './test_helpers.mjs'

test('creates a tag release and uploads a binary APK with a bounded long timeout', async () => {
  await withAsset(Buffer.from('signed-apk-bytes'), async (asset) => {
    const calls = []
    const fetchImpl = async (url, init = {}) => {
      calls.push({ url: String(url), init })
      const parsed = new URL(url)
      if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) {
        return json({ message: 'not found' }, 404)
      }
      if (parsed.pathname === `${releasePath}/releases` && init.method === 'POST') {
        return json({ ...release, html_url: 'https://github.test/release' }, 201)
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
        return json([])
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'POST') {
        assert.equal(parsed.searchParams.get('name'), asset.name)
        assert.equal(init.headers.Authorization, 'Bearer write-token')
        assert.ok(init.signal)
        assert.equal(parsed.host, 'uploads.example.test')
        assert.equal(init.headers['Content-Type'], 'application/octet-stream')
        assert.deepEqual(Buffer.from(init.body), Buffer.from('signed-apk-bytes'))
        return json({ id: 91, name: asset.name, size: asset.size, digest: asset.digest }, 201)
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

    assert.equal(result.release.id, 73)
    assert.equal(result.uploaded.length, 1)
    assert.equal(result.uploaded[0].name, asset.name)
    assert.equal(calls.length, 4)
  })
})

test('recovers a lost upload response by listing the already-created asset', async () => {
  await withAsset(Buffer.from('same-release-artifact'), async (asset) => {
    let uploadCalls = 0
    let listCalls = 0
    const fetchImpl = async (url, init = {}) => {
      const parsed = new URL(url)
      if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) return json(release)
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
        listCalls += 1
        return json(uploadCalls === 0 ? [] : [{ id: 91, name: asset.name, size: asset.size, digest: asset.digest }])
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'POST') {
        uploadCalls += 1
        throw new TypeError('connection closed after server accepted upload')
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

    assert.equal(uploadCalls, 1)
    assert.equal(listCalls, 2)
    assert.deepEqual(result.uploaded.map((item) => item.name), [asset.name])
  })
})
