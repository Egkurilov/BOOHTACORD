import type { ScreenViewerCard } from './screen_viewer_controller'

export function findParticipantScreen(screens: ScreenViewerCard[], participantId: string): ScreenViewerCard | null {
  return screens.find((screen) => screen.participantId === participantId) ?? null
}
