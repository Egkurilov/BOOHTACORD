import type { LocalIdentity } from './types'

export const buildIdentity: LocalIdentity = {
  release_id: __APP_RELEASE_ID__,
  release_order: __APP_RELEASE_ORDER__,
  platform: 'web',
  version: __APP_VERSION__,
  native_build: __APP_NATIVE_BUILD__,
}

export const buildLabel = `Версия ${__APP_VERSION__} (${__APP_NATIVE_BUILD__})`
