import { apiBaseUrl } from '../config/runtime'

export interface AuthenticationInput {
  login: string
  password: string
}

export type AuthenticationRequest = (input: string, init: RequestInit) => Promise<Response>

async function errorMessage(response: Response): Promise<string> {
  try {
    const source: unknown = await response.json()
    if (typeof source === 'object' && source !== null && !Array.isArray(source)) {
      const error = (source as Record<string, unknown>).error
      if (typeof error === 'object' && error !== null && !Array.isArray(error)) {
        const message = (error as Record<string, unknown>).message
        if (typeof message === 'string' && message.length > 0) return message
      }
    }
  } catch {
    // The status below remains safe to display when the server has no JSON error body.
  }
  return `Не удалось выполнить запрос (${response.status}).`
}

async function send(path: string, input: AuthenticationInput, request: AuthenticationRequest): Promise<void> {
  const response = await request(`${apiBaseUrl}${path}`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify(input),
  })
  if (!response.ok) throw new Error(await errorMessage(response))
}

export function login(input: AuthenticationInput, request: AuthenticationRequest = fetch): Promise<void> {
  return send('/auth/login', input, request)
}

export function register(input: AuthenticationInput, request: AuthenticationRequest = fetch): Promise<void> {
  return send('/auth/register', input, request)
}
