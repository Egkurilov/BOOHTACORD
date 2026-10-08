export interface ScreenMediaRollout {
  readonly descriptor: boolean
  readonly jpegPreview: boolean
  readonly codecPolicy: boolean
  readonly boundedSimulcast: boolean
}
export function screenMediaRollout(source: Readonly<Record<string, unknown>> = import.meta.env): ScreenMediaRollout {
  const flag = (name: string, fallback: boolean) => source[name] === 'true' ? true : source[name] === 'false' ? false : fallback
  return Object.freeze({
    descriptor: flag('VITE_SCREEN_SHARE_DESCRIPTOR_V1', true),
    jpegPreview: flag('VITE_SCREEN_PREVIEWS_V1', true),
    codecPolicy: flag('VITE_SCREEN_SHARE_CODEC_POLICY', true),
    boundedSimulcast: flag('VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', false),
  })
}
