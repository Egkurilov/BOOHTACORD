import { fields } from './generated'
export function validField(key: string, value: unknown): boolean {
 const field = fields[key]
 if (!field) return false
 const validLength = (input: string) => input.length >= (field.minLength ?? 0) && input.length <= (field.maxLength ?? Number.MAX_SAFE_INTEGER)
 switch(field.type) {
  case 'id': return typeof value === 'string' && validLength(value) && new RegExp(field.pattern ?? 'a^').test(value) && !/^0+$/.test(value)
  case 'version': return typeof value === 'string' && validLength(value) && new RegExp(field.pattern ?? 'a^').test(value)
  case 'enum': return typeof value === 'string' && validLength(value) && (field.values?.includes(value) ?? false)
  default: return typeof value === 'number' && Number.isFinite(value) && value >= field.min! && value <= field.max! && (field.type !== 'integer' || Number.isInteger(value))
 }
}

