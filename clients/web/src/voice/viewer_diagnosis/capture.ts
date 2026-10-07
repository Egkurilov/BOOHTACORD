const unknown={capturedFrames:null,encodedFrames:null}
function counter(value:unknown):number|null {return typeof value==='number'&&Number.isSafeInteger(value)&&value>=0?value:null}
export function sourceCountersFromReport(reports:RTCStatsReport):{capturedFrames:number|null;encodedFrames:number|null} {
  let outbound:Record<string,unknown>|null=null,pixels=-1
  reports.forEach(report=>{if(report.type!=='outbound-rtp'||(report.kind ?? report.mediaType)!=='video'||report.active!==true) return
    const size=Number(report.frameWidth ?? 0)*Number(report.frameHeight ?? 0);if(size>pixels){outbound=report;pixels=size}})
  const selected=outbound as Record<string,unknown>|null
  if(!selected) return {...unknown}
  const source=typeof selected.mediaSourceId==='string'?reports.get(selected.mediaSourceId):null
  return {capturedFrames:source?.type==='media-source'?counter(source.frames):null,encodedFrames:counter(selected.framesEncoded)}
}
export async function readSourceCounters(sender:Pick<RTCRtpSender,'getStats'>|undefined):Promise<{capturedFrames:number|null;encodedFrames:number|null}> {
  if(!sender) return {...unknown}
  try {return sourceCountersFromReport(await sender.getStats())} catch{return {...unknown}}
}
