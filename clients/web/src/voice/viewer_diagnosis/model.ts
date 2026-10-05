export const states=['idle','ended','background','connecting','no_first_frame','stale_metrics','frozen','no_audio','playing'] as const
export type DiagnosisState=typeof states[number]
export type DiagnosisAction='none'|'retry'|'refresh'|'choose'|'publisher'
export interface Input {selected:boolean;ended:boolean;visible:boolean;local:boolean;hasAudio:boolean;videoReady:boolean;presentedFps:number|null;sampledAt:number|null;selectedAt:number;now:number}
export function diagnose(input:Input):{state:DiagnosisState;message:string;action:DiagnosisAction;label:string} {
  if(input.ended) return {state:'ended',message:'Демонстрация завершена.',action:'choose',label:'Выбрать другую демонстрацию'}
  if(!input.selected) return {state:'idle',message:'Выберите демонстрацию.',action:'none',label:''}
  if(!input.visible) return {state:'background',message:'Окно в фоне. Обновление кадров может быть приостановлено браузером.',action:'none',label:''}
  if(!input.videoReady) return input.now-input.selectedAt<8000
    ? {state:'connecting',message:'Ожидаем первый кадр.',action:'none',label:''}
    : {state:'no_first_frame',message:'Первый кадр пока не получен.',action:'retry',label:'Повторить подключение к демонстрации'}
  if(!input.local&&(input.sampledAt===null||input.now-input.sampledAt>6000||input.now<input.sampledAt)) return {state:'stale_metrics',message:'Данные о приёме отсутствуют или устарели. Причина качества не определена.',action:'refresh',label:'Обновить измерения'}
  if(input.presentedFps===0) return {state:'frozen',message:'Показанные кадры не обновляются. Это не определяет причину на источнике.',action:'retry',label:'Повторить подключение к демонстрации'}
  if(!input.hasAudio) return {state:'no_audio',message:'Источник не публикует аудиодорожку.',action:'publisher',label:'Как добавить звук'}
  return {state:'playing',message:'Демонстрация воспроизводится.',action:'none',label:''}
}
