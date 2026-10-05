import { DEFAULT, validPreference, type ConversationKind, type Preference } from './policy'
type Storage = Pick<globalThis.Storage,'getItem'|'setItem'>
const validKey = (key:string) => /^(CHANNEL|DIRECT_MESSAGE):[a-zA-Z0-9-]{1,80}$/.test(key)
export function createConversationPreferences(account:string, storage:Storage|null) {
  const key=`boohtacord:notification:${account}:conversations:v1`
  let memory:Record<string,Preference>={}
  function read():Record<string,Preference>|null {
    try {
      if (!storage) return memory
      const raw=storage.getItem(key)
      if (!raw) return {}
      if (raw.length>32768) return null
      const data:unknown=JSON.parse(raw)
      if (!data || typeof data!=='object' || Array.isArray(data)) return null
      const entries=Object.entries(data)
      if (entries.length>100 || entries.some(([scope,value])=>!validKey(scope)||!validPreference(value))) return null
      return Object.fromEntries(entries)
    } catch { return null }
  }
  function get(kind:ConversationKind,id:string):Preference {
    const values=read()
    return { ...(values===null ? {mode:'none' as const,pausedUntil:0} : values[`${kind}:${id}`] ?? DEFAULT) }
  }
  function set(kind:ConversationKind,id:string,value:Preference):void {
    const scope=`${kind}:${id}`
    if (!validKey(scope)||!validPreference(value)) throw new Error('Некорректные настройки уведомлений.')
    const values=read()
    if (values===null) throw new Error('Настройки уведомлений повреждены. Сбросьте их перед изменением.')
    if (value.mode==='all' && value.pausedUntil===0) delete values[scope]
    else {
      if (!values[scope] && Object.keys(values).length>=100) throw new Error('Достигнут предел настроек для 100 бесед. Сбросьте настройки одной из них.')
      values[scope]={...value}
    }
    storage?.setItem(key,JSON.stringify(values));memory=values
  }
  function reset():void { storage?.setItem(key,'{}');memory={} }
  return { get,set,reset }
}
