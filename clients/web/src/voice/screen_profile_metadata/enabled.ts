export function screenDescriptorMetadataEnabled(): boolean {
  return import.meta.env.VITE_SCREEN_SHARE_DESCRIPTOR_V1 !== 'false'
}
