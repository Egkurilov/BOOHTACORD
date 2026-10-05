import { draftMemoryEpoch } from '../draft_memory'
import type { Position } from './dom'
const memory = new Map<string, Position>()
let epoch = draftMemoryEpoch()
function current(): void { if (epoch !== draftMemoryEpoch()) { epoch = draftMemoryEpoch(); memory.clear() } }
export function savePosition(key: string, position: Position): void { current(); memory.set(key, { ...position }); if (memory.size > 100) memory.delete(memory.keys().next().value!) }
export function loadPosition(key: string): Position | null { current(); return memory.has(key) ? { ...memory.get(key)! } : null }
