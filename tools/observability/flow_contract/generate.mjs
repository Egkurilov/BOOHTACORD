import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..')
const schema = JSON.parse(fs.readFileSync(path.join(root, 'contracts/telemetry-flow-v1.json')))
const fixtures = JSON.parse(fs.readFileSync(path.join(root, 'contracts/telemetry-flow-v1.fixtures.json')))
const targets = new Map()
targets.set('backend/internal/observability/flow_contract/generated.go',
  '// Code generated from telemetry-flow-v1.json; DO NOT EDIT.\npackage flowcontract\n\nconst Version = 1\n\nvar Operations = map[string]bool{\n' +
  schema.operations.map(x => JSON.stringify(x)+': true,').join('\n') + '\n}\n\nvar Fields = map[string]Field{\n' +
  Object.entries(schema.fields).map(([key,f]) => JSON.stringify(key)+': {Kind: '+JSON.stringify(f.type)+
    ', Min: '+(f.min??0)+', Max: '+(f.max??0)+', Values: []string{'+(f.values??[]).map(x=>JSON.stringify(x)).join(',')+'}},').join('\n')+'\n}\n')
targets.set('clients/web/src/telemetry/flow_contract/generated.ts',
  '// Code generated from telemetry-flow-v1.json; DO NOT EDIT.\nexport const operations = '+JSON.stringify(schema.operations)+' as const\nexport const fields: Record<string, {type: string; min?: number; max?: number; values?: readonly string[]; owner: string}> = {\n' +
  Object.entries(schema.fields).map(([key,f])=>JSON.stringify(key)+': '+JSON.stringify(f)+',').join('\n')+'\n}\n')
targets.set('clients/web/src/telemetry/flow_contract/fixtures.ts',
  '// Code generated from telemetry-flow-v1.fixtures.json; DO NOT EDIT.\nexport default '+JSON.stringify(fixtures)+' as const\n')
targets.set('clients/flutter/lib/src/features/telemetry/flow_contract/generated.dart',
  '// Code generated from telemetry-flow-v1.json; DO NOT EDIT.\nconst flowOperations = '+JSON.stringify(schema.operations)+';\nconst flowFields = <String, Map<String, Object>>{\n' +
  Object.entries(schema.fields).map(([key,f])=>JSON.stringify(key)+': '+JSON.stringify(f)+',').join('\n')+'\n};\n')
let stale = false
for (const [name, raw] of targets) {
  const content=name.endsWith('.go')?execFileSync('gofmt',[],{input:raw,encoding:'utf8'}):raw
  const target = path.join(root,name)
  if (process.argv.includes('--check')) {
    if (!fs.existsSync(target) || fs.readFileSync(target,'utf8').replaceAll('\r\n','\n') !== content) {
      process.stderr.write('Stale flow contract: '+name+'\n'); stale = true
    }
  } else {
    fs.mkdirSync(path.dirname(target),{recursive:true}); fs.writeFileSync(target,content)
  }
}
if (stale) process.exitCode = 1

