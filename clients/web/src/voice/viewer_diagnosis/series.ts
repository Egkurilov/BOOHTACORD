import { ref } from 'vue'
import { sanitizeSample,type Sample } from './bundle'
export function createDiagnosisSeries(read:()=>Record<string,unknown>,clock=()=>performance.now()) {
  const samples=ref<Sample[]>([]),collecting=ref(false)
  let start=0,timer:ReturnType<typeof setInterval>|null=null
  function stop():void {if(timer) clearInterval(timer);timer=null;collecting.value=false}
  function sample():void {
    const elapsedMs=clock()-start
    if(elapsedMs<0||elapsedMs>=60000||samples.value.length>=30){stop();return}
    samples.value.push(sanitizeSample({...read(),elapsedMs}))
  }
  function begin():void {stop();samples.value=[];start=clock();collecting.value=true;sample();timer=setInterval(sample,2000)}
  function clear():void {stop();samples.value=[]}
  return {samples,collecting,begin,stop,clear}
}
