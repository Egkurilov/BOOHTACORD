import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtemp, rm, stat, writeFile } from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

import { publishGitVerseRelease } from './publish.mjs'

const apiRoot = 'https://api.example.test'
const releasePath = '/repos/egkurilov/BOOHTACORD'
const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { 'content-type': 'application/json' },
})

async function withAsset(content, run) {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'boohtacord-release-test-'))
  const file = path.join(directory, 'BOOHTACORD-android-v1.0.15-arm64-v8a.apk')
  await writeFile(file, content)
  try {
    await run({ path: file, name: path.basename(file), size: (await stat(file)).size })
  } finally {
    await rm(directory, { recursive: true, force: true })
  }
}

test('creates a tag release and uploads an APK with multipart and a bounded long timeout', async () => {
  await withAsset(Buffer.from('signed-apk-bytes'), async (asset) => {
    const calls = []
    const fetchImpl = async (url, init = {}) => {
      calls.push({ url: String(url), init })
      const parsed = new URL(url)
      if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) {
        return json({ message: 'not found' }, 404)
      }
      if (parsed.pathname === `${releasePath}/releases` && init.method === 'POST') {
        return json({ id: 73, tag_name: 'android-v1.0.15', html_url: 'https://gitverse.test/release' }, 201)
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
        return json([])
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'POST') {
        assert.equal(parsed.searchParams.get('name'), asset.name)
        assert.equal(init.headers.Authorization, 'Bearer write-token')
        assert.ok(init.signal)
        assert.ok(init.body instanceof FormData)
        const attachment = init.body.get('attachment')
        assert.ok(attachment instanceof Blob)
        assert.equal(attachment.name, asset.name)
        assert.deepEqual(Buffer.from(await attachment.arrayBuffer()), Buffer.from('signed-apk-bytes'))
        return json({ id: 91, name: asset.name, size: asset.size }, 201)
      }
      assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
    }

    const result = await publishGitVerseRelease({
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
    const release = { id: 73, tag_name: 'android-v1.0.15' }
    const fetchImpl = async (url, init = {}) => {
      const parsed = new URL(url)
      if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) return json(release)
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
        listCalls += 1
        return json(uploadCalls === 0 ? [] : [{ id: 91, name: asset.name, size: asset.size }])
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'POST') {
        uploadCalls += 1
        throw new TypeError('connection closed after server accepted upload')
      }
      assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
    }

    const result = await publishGitVerseRelease({
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

test('skips an identical asset when a tag-triggered job is safely retried', async () => {
  await withAsset(Buffer.from('already-published'), async (asset) => {
    const calls = []
    const fetchImpl = async (url, init = {}) => {
      calls.push({ url: String(url), method: init.method ?? 'GET' })
      const parsed = new URL(url)
      if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) {
        return json({ id: 73, tag_name: 'android-v1.0.15' })
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets`) {
        return json([{ id: 91, name: asset.name, size: asset.size }])
      }
      assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
    }

    const result = await publishGitVerseRelease({
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
        return json({ id: 73, tag_name: 'android-v1.0.15' })
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
        assetLists += 1
        return json([])
      }
      if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'POST') {
        uploadCalls += 1
        if (uploadCalls === 1) return json({ message: 'temporarily unavailable' }, 503)
        return json({ id: 92, name: asset.name, size: asset.size }, 201)
      }
      assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
    }

    const result = await publishGitVerseRelease({
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

test('rejects without a token or before uploading a conflicting same-name asset', async () => {
  await withAsset(Buffer.from('new-build'), async (asset) => {
    let calls = 0
    const fetchImpl = async () => {
      calls += 1
      return json({ id: 73, tag_name: 'android-v1.0.15' })
    }

    await assert.rejects(
      publishGitVerseRelease({
        tag: 'android-v1.0.15', title: 'release', body: '', assets: [asset.path],
        token: '', apiRoot, fetchImpl,
      }),
      /RELEASE_API_KEY is required/,
    )
    assert.equal(calls, 0)

    await assert.rejects(
      publishGitVerseRelease({
        tag: 'android-v1.0.15', title: 'release', body: '', assets: [asset.path],
        token: 'write-token', apiRoot,
        fetchImpl: async (url, init = {}) => {
          const parsed = new URL(url)
          if (parsed.pathname.endsWith('/releases/tags/android-v1.0.15')) {
            return json({ id: 73, tag_name: 'android-v1.0.15' })
          }
          if (parsed.pathname === `${releasePath}/releases/73/assets` && init.method === 'GET') {
            return json([{ id: 91, name: asset.name, size: asset.size + 1 }])
          }
          assert.fail(`Unexpected request: ${init.method ?? 'GET'} ${url}`)
        },
      }),
      /conflicting existing asset/,
    )
  })
})

test('runs the publisher CLI on the current platform and fails closed without its secret', () => {
  const script = fileURLToPath(new URL('./publish.mjs', import.meta.url))
  const result = spawnSync(process.execPath, [
    script,
    '--tag',
    'android-v1.0.15',
    '--asset',
    'not-read-without-a-token.apk',
  ], {
    encoding: 'utf8',
    env: {
      ...process.env,
      GITHUB_REPOSITORY: 'egkurilov/BOOHTACORD',
      RELEASE_API_KEY: '',
    },
  })

  assert.equal(result.status, 1)
  assert.match(result.stderr, /RELEASE_API_KEY is required/)
})
