import { states,type DiagnosisState } from './model'
export interface Sample {elapsedMs:number;state:DiagnosisState;captureFps:number|null;encodedFps:number|null;decodedFps:number|null;presentedFps:number|null;bitrateKbps:number|null;rttMs:number|null;sampleAgeMs:number|null;capturedFrames:number|null;encodedFrames:number|null;decodedFrames:number|null;presentedFrames:number|null}
export interface Bundle {schema:'boohtacord.viewer-diagnosis.v1';receivers:Array<{slot:1|2;samples:Sample[]}>}
function bounded(value:unknown,max:number):number|null {return typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=max?Math.round(value*10)/10:null}
export function sanitizeSample(input:unknown):Sample {
  if(!input||typeof input!=='object') throw new Error('Некорректный образец.')
  const value=input as Record<string,unknown>,elapsedMs=bounded(value.elapsedMs,60000)
  if(elapsedMs===null||!states.includes(value.state as DiagnosisState)) throw new Error('Некорректное состояние или время образца.')
  const count=(key:string)=>typeof value[key]==='number'&&Number.isSafeInteger(value[key])&&Number(value[key])>=0?Number(value[key]):null
  return {elapsedMs,state:value.state as DiagnosisState,captureFps:bounded(value.captureFps,240),encodedFps:bounded(value.encodedFps,240),decodedFps:bounded(value.decodedFps,240),presentedFps:bounded(value.presentedFps,240),bitrateKbps:bounded(value.bitrateKbps,100000),rttMs:bounded(value.rttMs,60000),sampleAgeMs:bounded(value.sampleAgeMs,60000),capturedFrames:count('capturedFrames'),encodedFrames:count('encodedFrames'),decodedFrames:count('decodedFrames'),presentedFrames:count('presentedFrames')}
}
export function buildBundle(first:unknown[],second?:unknown[]):Bundle {
  const samples=(values:unknown[])=>{if(values.length>30) throw new Error('Не более 30 образцов на приёмник.');return values.map(sanitizeSample)}
  return {schema:'boohtacord.viewer-diagnosis.v1',receivers:[{slot:1,samples:samples(first)},...(second?[{slot:2 as const,samples:samples(second)}]:[])]}
}
export function parseBundle(text:string):Bundle {
  if(text.length>32768) throw new Error('Диагностический файл слишком большой.')
  const value=JSON.parse(text)
  if(value?.schema!=='boohtacord.viewer-diagnosis.v1'||!Array.isArray(value.receivers)||value.receivers.length<1||value.receivers.length>2) throw new Error('Неизвестный формат диагностики.')
  if(value.receivers.some((r:Record<string,unknown>,index:number)=>r?.slot!==index+1||!Array.isArray(r.samples))) throw new Error('Некорректные приёмники.')
  return buildBundle(value.receivers[0].samples,value.receivers[1]?.samples)
}
