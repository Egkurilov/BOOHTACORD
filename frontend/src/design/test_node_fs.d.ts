declare module 'node:fs' {
  export function readFileSync(path: URL, options: 'utf8'): string
}
