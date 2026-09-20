const accountMetadata = /^account:([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i

export function accountIdFromMetadata(metadata: string | undefined): string | null {
  const match = metadata?.match(accountMetadata)
  return match ? match[1].toLowerCase() : null
}
