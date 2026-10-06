import { fields } from './generated'
export function validField(key: string, value: unknown): boolean {
 const field = fields[key]
 if (!field) return false
 switch(field.type) {
  case 'id': return typeof value === 'string' && /^[0-9a-f]{32}$/.test(value) && !/^0+$/.test(value)
  case 'version': return typeof value === 'string' && /^[a-zA-Z0-9][a-zA-Z0-9.+_-]{0,31}$/.test(value)
  case 'enum': return typeof value === 'string' && (field.values?.includes(value) ?? false)
  default: return typeof value === 'number' && Number.isFinite(value) && value >= field.min! && value <= field.max! && (field.type !== 'integer' || Number.isInteger(value))
 }
}

