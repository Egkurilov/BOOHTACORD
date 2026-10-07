import { accountIdFromMetadata } from './participant_identity'
import { captureLocalScreenThumbnails, type LocalScreenThumbnailTrack } from './screen_thumbnail'
import { LatestScreenPreviewUploader } from './screen_preview_uploader'

interface PreviewPublication {
  source: string
  videoTrack?: LocalScreenThumbnailTrack
}
interface PreviewParticipant {
  identity: string
  metadata: string
  getTrackPublication(source: string): PreviewPublication | undefined
}
interface PreviewRoom {
  on(event: unknown, handler: (publication?: PreviewPublication) => void): unknown
  localParticipant: PreviewParticipant
  remoteParticipants: Map<string, PreviewParticipant>
}
interface PreviewViewer {
  viewer: {
    setThumbnail(participantId: string, bytes: Uint8Array): void
    removeThumbnail(participantId: string): void
  }
}
interface PreviewEvents {
  trackPublished: unknown
  trackUnpublished: unknown
  disconnected: unknown
}

export function bindLiveKitScreenPreview(
  room: PreviewRoom,
  viewer: PreviewViewer,
  events: PreviewEvents,
  screenSource: string,
) {
  const uploader = new LatestScreenPreviewUploader()
  let leaseId: string | null = null
  let stopCapture: (() => void) | null = null
  const localId = () => accountIdFromMetadata(room.localParticipant.metadata) ?? room.localParticipant.identity
  const stop = () => {
    stopCapture?.()
    stopCapture = null
    void uploader.stop()
  }
  const start = (track: LocalScreenThumbnailTrack, participantId: string) => {
    stopCapture?.()
    stopCapture = captureLocalScreenThumbnails(track, (bytes) => {
      viewer.viewer.setThumbnail(participantId, bytes)
      if (leaseId) uploader.offer(bytes)
    })
    if (leaseId) void uploader.start(leaseId).catch(() => undefined)
  }
  room.on(events.trackPublished, (publication) => {
    if (publication?.source !== screenSource || !publication.videoTrack) return
    start(publication.videoTrack, localId())
  })
  room.on(events.trackUnpublished, (publication) => {
    if (publication?.source !== screenSource) return
    stop()
    viewer.viewer.removeThumbnail(localId())
  })
  room.on(events.disconnected, stop)
  return {
    bindLease(value: string) {
      leaseId = value
      const publication = room.localParticipant.getTrackPublication(screenSource)
      if (publication?.videoTrack) start(publication.videoTrack, localId())
    },
    apply(lease: string, bytes: Uint8Array) {
      const participant = room.remoteParticipants.get(`voice-lease:${lease}`)
      if (!participant?.getTrackPublication(screenSource)) return
      viewer.viewer.setThumbnail(accountIdFromMetadata(participant.metadata) ?? participant.identity, bytes)
    },
    clear(lease: string) {
      const participant = room.remoteParticipants.get(`voice-lease:${lease}`)
      if (participant) viewer.viewer.removeThumbnail(accountIdFromMetadata(participant.metadata) ?? participant.identity)
    },
  }
}
