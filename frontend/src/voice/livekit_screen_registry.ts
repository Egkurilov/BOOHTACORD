import type { ScreenViewerPublication, ScreenViewerStream } from './screen_viewer_controller'

export interface RemoteScreenParticipant {
  accountId?: string
  audio?: ScreenViewerPublication
  identity: string
  name?: string
  video?: ScreenViewerPublication
}

export class LiveKitScreenRegistry {
  private current: ScreenViewerStream[] = []

  refresh(participants: RemoteScreenParticipant[], selectedId: string | null): void {
    this.current = participants.flatMap((participant) => participant.video ? [{
      audio: participant.audio,
      accountId: participant.accountId,
      hasAudio: participant.audio !== undefined,
      id: `${participant.identity}:screen`,
      participantId: participant.identity,
      participantName: participant.name || participant.identity,
      video: participant.video,
    }] : [])
    this.current.filter((stream) => stream.id !== selectedId).forEach((stream) => {
      stream.video.setSubscribed(false)
      stream.audio?.setSubscribed(false)
    })
  }

  streams(): ScreenViewerStream[] {
    return this.current
  }
}
