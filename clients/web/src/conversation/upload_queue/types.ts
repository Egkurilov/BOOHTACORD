import type { ShallowRef } from 'vue'

export interface Prepared { id: string; originalName: string; sizeBytes: number }
export interface UploadControl { signal: AbortSignal; onProgress: (percent: number) => void }
export type Upload<T extends Prepared> = (scope: string, file: File, control: UploadControl) => Promise<T>
export interface Emit<T> { (event: 'change', value: T[]): void; (event: 'pending', value: boolean): void }
export interface Item<T extends Prepared> {
  key: number; name: string; sizeBytes: number; file?: File; attachment?: T
  status: 'queued' | 'uploading' | 'failed' | 'done'; progress: number; error?: string
}
export interface State<T extends Prepared> {
  items: ShallowRef<Item<T>[]>; version: number; running: Promise<void> | null
  active: AbortController | null; scope: () => string; upload: Upload<T>
  publish: () => void; failed: (cause: unknown) => void
}
