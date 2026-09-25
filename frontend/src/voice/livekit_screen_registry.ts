import type { ScreenViewerPublication, ScreenViewerStream } from './screen_viewer_controller'

export interface ScreenParticipantPublication {
  accountId?: string
  audio?: ScreenViewerPublication
  identity: string
  isLocal?: boolean
  name?: string
  video?: ScreenViewerPublication
}

export class LiveKitScreenRegistry {
  private current: ScreenViewerStream[] = []

  refresh(participants: ScreenParticipantPublication[], selectedId: string | null): void {
    this.current = participants.flatMap((participant) => participant.video ? [{
      audio: participant.isLocal ? undefined : participant.audio,
      accountId: participant.accountId,
      hasAudio: !participant.isLocal && participant.audio !== undefined,
      id: participant.isLocal ? `local:${participant.identity}:screen` : `${participant.identity}:screen`,
      isLocal: participant.isLocal,
      participantId: participant.identity,
      participantName: participant.isLocal ? 'Ваш экран' : participant.name?.trim() || 'Участник',
      video: participant.video,
    }] : [])
    this.current.filter((stream) => stream.id !== selectedId && !stream.isLocal).forEach((stream) => {
      stream.video.setSubscribed?.(false)
      stream.audio?.setSubscribed?.(false)
    })
  }

  streams(): ScreenViewerStream[] {
    return this.current
  }
}
