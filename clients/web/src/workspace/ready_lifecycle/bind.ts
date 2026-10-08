import { onBeforeUnmount, onMounted } from 'vue'
import type { ActionScope } from '../../telemetry/action_scope/scope'
import { observeWorkspace } from '../../telemetry/observe_render/workspace'

interface WorkspaceReadyPorts {
  readiness?: ActionScope
  start(): void
  refresh(): Promise<unknown>
  failed(): boolean
  stop(): void
}

export function bindWorkspaceReady(ports: WorkspaceReadyPorts): void {
  let mounted = true
  onMounted(() => {
    ports.start()
    void observeWorkspace(ports.readiness, async () => { await ports.refresh() },
      () => mounted, ports.failed)
  })
  onBeforeUnmount(() => {
    mounted = false
    ports.readiness?.finish('cancelled', 'disposed')
    ports.stop()
  })
}
