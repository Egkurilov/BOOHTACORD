import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'

const document = JSON.parse(readFileSync(new URL('../../contracts/client-build.json', import.meta.url), 'utf8'))
const build = document.builds.web
const buildInfo = { schema_version:1, application_family:document.application_family, ...build }
const buildInfoJSON = JSON.stringify(buildInfo, null, 2) + '\n'
const digest = createHash('sha256').update(buildInfoJSON).digest('hex')

export default defineConfig({
  define: {
    __APP_RELEASE_ID__: JSON.stringify(build.release_id),
    __APP_RELEASE_ORDER__: JSON.stringify(build.release_order),
    __APP_VERSION__: JSON.stringify(build.version),
    __APP_NATIVE_BUILD__: JSON.stringify(build.native_build),
  },
  plugins: [vue(), { name:'client-build-info', generateBundle() {
    this.emitFile({ type:'asset', fileName:'build-info.json', source:buildInfoJSON })
    this.emitFile({ type:'asset', fileName:'release-receipt.json', source:JSON.stringify({ ...buildInfo, architecture:'any', build_info_sha256:digest, source_revision:process.env.SOURCE_REVISION ?? 'unknown', signature_evidence:'oci_attestation', download_available:true }, null, 2)+'\n' })
  } }],
  test: {
    environment: 'node',
    include: ['src/**/*.spec.ts'],
  },
})
