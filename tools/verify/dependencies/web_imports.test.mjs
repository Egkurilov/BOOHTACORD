import assert from 'node:assert/strict'
import { test } from 'node:test'
import { importsOf } from './web_imports.mjs'

test('compiler imports include type, re-export and dynamic imports', () => {
  assert.deepEqual(importsOf(`import type { X } from './types'
    export { x } from './public'; const lazy = import('./lazy')`, 'module.ts'), ['./types', './public', './lazy'])
})
test('strings and comments are not dependency edges', () => {
  assert.deepEqual(importsOf(`// import X from './comment'
    const assertion = "@import './design/file.css'";`, 'test.ts'), [])
})
test('Vue scripts are parsed independently of the template', () => {
  assert.deepEqual(importsOf(`<script setup lang="ts">import Header from './Header.vue'</script>
    <template>import './not-code'</template>`, 'Panel.vue'), ['./Header.vue'])
})
