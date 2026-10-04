export const generatedPasswordLength = 24
const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
const lower = 'abcdefghijklmnopqrstuvwxyz'
const digits = '0123456789'
const symbols = '!@#$%^&*_-+='
const alphabet = upper + lower + digits + symbols

export type RandomBytesSource = (bytes: Uint8Array) => void

function webCryptoBytes(bytes: Uint8Array): void {
  const cryptoApi = globalThis.crypto
  if (!cryptoApi?.getRandomValues) throw new Error('Web Crypto is unavailable.')
  cryptoApi.getRandomValues(bytes)
}

function randomIndex(max: number, source: RandomBytesSource): number {
  const limit = 256 - (256 % max)
  const byte = new Uint8Array(1)
  do source(byte); while (byte[0] >= limit)
  return byte[0] % max
}

function pick(chars: string, source: RandomBytesSource): string { return chars[randomIndex(chars.length, source)] }

export function generateSecurePassword(source: RandomBytesSource = webCryptoBytes): string {
  const result = [pick(upper, source), pick(lower, source), pick(digits, source), pick(symbols, source)]
  while (result.length < generatedPasswordLength) result.push(pick(alphabet, source))
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swap = randomIndex(index + 1, source)
    const current = result[index]; result[index] = result[swap]; result[swap] = current
  }
  return result.join('')
}

