const metadataKeys = ['app.media.direction', 'app.media.sample_state', 'app.media.source', 'app.sample.age_ms',
  'app.media.stats_window_ms', 'app.media.stats_source', 'app.media.presentation_source', 'app.media.collection_state']
/** Reserve one attribute for relay's trusted user enrichment (32-attribute contract). */
export function mediaSampleChunks(core: Record<string, string | number>, sampled: Record<string, string | number>): Record<string, string | number>[] {
  const metadata: Record<string, string | number> = {}, values = { ...sampled }
  for (const key of metadataKeys) if (values[key] !== undefined) { metadata[key] = values[key]!; delete values[key] }
  const entries = Object.entries(values), limit = 31 - Object.keys(core).length - Object.keys(metadata).length
  if (limit <= 0) return []
  const chunks: Record<string, string | number>[] = []
  for (let offset = 0; offset < Math.max(1, entries.length); offset += limit)
    chunks.push({ ...core, ...metadata, ...Object.fromEntries(entries.slice(offset, offset + limit)) })
  return chunks
}
