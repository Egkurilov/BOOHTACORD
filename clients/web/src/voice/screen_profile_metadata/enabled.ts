import { screenMediaRollout } from '../screen_rollout/policy'
export function screenDescriptorMetadataEnabled(): boolean {
  return screenMediaRollout().descriptor
}
