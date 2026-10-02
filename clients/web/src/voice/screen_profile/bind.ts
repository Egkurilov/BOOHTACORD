import type { VoiceRoom } from '../livekit_gateway'
import { ScreenProfileGuard } from './guard'
import type { ProfileTrack } from './types'

export function bindScreenProfile(room: VoiceRoom, readTrack: () => ProfileTrack | undefined): () => void {
  const guard = new ScreenProfileGuard(readTrack)
  const read = room.readScreenDiagnostics!.bind(room), disconnect = room.disconnect.bind(room)
  room.stopScreenProfileChecks = () => guard.stop()
  room.disconnect = () => { guard.stop(); return disconnect() }
  room.readScreenDiagnostics = async () => {
    await guard.check()
    return { ...await read(), profileCheck: guard.snapshot }
  }
  room.localParticipant.updateScreenShareProfile = (profile) => guard.apply(profile)
  return () => guard.stop()
}
