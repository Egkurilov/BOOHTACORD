import { LogLevel, Room, RoomEvent, Track, setLogLevel } from 'livekit-client'
import type { RemoteTrack } from 'livekit-client'
import { BaselinePresentation } from './presentation'

type Credentials = { url: string; token: string; role: 'publisher' | 'viewer'; numberedSynthetic?: boolean }

export async function connectBaselineRoom(
  credentials: Credentials,
  presentation: BaselinePresentation,
  acceptRoom: (room: Room) => void,
  setStatus: (value: string) => void,
  acceptRemoteTrack: (track: RemoteTrack) => void,
): Promise<void> {
  setLogLevel(LogLevel.silent)
  const room = new Room({ adaptiveStream: false, dynacast: false })
  acceptRoom(room)
  presentation.start(performance.now())
  room.on(RoomEvent.TrackSubscribed, track => {
    if (credentials.role !== 'viewer' || track.kind !== Track.Kind.Video) return
    acceptRemoteTrack(track)
    const video = document.querySelector<HTMLVideoElement>('#remote')
    if (video) presentation.attach(track, video, credentials.numberedSynthetic === true)
  })
  try {
    await room.connect(credentials.url, credentials.token)
  } catch {
    setStatus('connect-failed')
    throw new Error('LiveKit connection failed; credentials are not included in reports.')
  }
}
