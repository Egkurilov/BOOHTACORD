import { toRaw } from 'vue'
import { observeMessageRender } from '../observe_render/messages'
import { createJourneyRecorder,type Outcome } from './state'
export const journeyRecorder=createJourneyRecorder()
let rendered=new WeakMap<object,(outcome:Outcome)=>void>()
export function markAccepted(message:object):void {if(journeyRecorder.active.value) rendered.set(toRaw(message),journeyRecorder.begin('accepted_rendered'))}
export function markRendered(message:object):void {observeMessageRender(message);const target=toRaw(message),finish=rendered.get(target);if(finish){rendered.delete(target);finish('completed')}}
let frames=new WeakMap<object,(outcome:Outcome)=>void>()
export function markScreenSelected(video:object|null):void {if(video&&journeyRecorder.active.value){frames.get(video)?.('cancelled');frames.set(video,journeyRecorder.begin('select_first_frame'))}}
export function markScreenFrame(video:object|null):void {if(!video) return;const finish=frames.get(video);if(finish){frames.delete(video);finish('completed')}}
export function stopJourneyRun():void {journeyRecorder.stop();rendered=new WeakMap();frames=new WeakMap()}
