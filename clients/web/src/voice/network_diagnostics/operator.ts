import type { NetworkDiagnostics } from './model'
import { exportNetworkDiagnostics } from './export'
declare global { interface Window { boohtacordVoiceNetworkReport?: () => Promise<string> } }
export function installNetworkReport(read: () => Promise<NetworkDiagnostics>): void {
  if (typeof window !== 'undefined') window.boohtacordVoiceNetworkReport = async () => exportNetworkDiagnostics(await read())
}
