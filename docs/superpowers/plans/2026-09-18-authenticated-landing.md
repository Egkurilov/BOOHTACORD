# Authenticated Landing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show an accessible Russian registration/login landing page before any protected workspace request, then enter the workspace using the secure server-side session cookie.

**Architecture:** `App.vue` becomes a thin session gate. It asks only the public-purpose session endpoint first; an expected `401` selects the landing view and never starts topology, DM or realtime clients. The existing workspace moves into a mounted-only component, while the identity leaf owns auth HTTP calls and the form.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vitest, existing Go API endpoints.

---

### Task 1: Add identity API clients and regression tests

**Files:**
- Modify: `frontend/src/identity/current_session.ts`
- Modify: `frontend/src/identity/current_session.spec.ts`
- Create: `frontend/src/identity/auth_client.ts`
- Create: `frontend/src/identity/auth_client.spec.ts`

- [ ] **Step 1: Test that a missing session is a guest state, not an application error**

```ts
await expect(loadCurrentSession(vi.fn().mockResolvedValue(new Response('', { status: 401 })))).resolves.toBeNull()
```

- [ ] **Step 2: Test credentialed JSON requests and API error messages**

```ts
await login({ login: 'egor', password: 'correct horse battery staple' }, request)
expect(request).toHaveBeenCalledWith('/api/v1/auth/login', expect.objectContaining({
  method: 'POST', credentials: 'same-origin', body: JSON.stringify({ login: 'egor', password: 'correct horse battery staple' }),
}))
```

- [ ] **Step 3: Implement the smallest typed API clients**

`loadCurrentSession` returns `null` only for HTTP 401; other unexpected responses remain errors. `login` and `register` use same-origin cookies and JSON bodies, and surface the server's bounded error message without logging credentials.

- [ ] **Step 4: Run the focused identity tests**

Run: `npm test -- --runInBand src/identity/current_session.spec.ts src/identity/auth_client.spec.ts`

Expected: both files pass.

### Task 2: Gate the workspace and expose a public authentication page

**Files:**
- Modify: `frontend/src/App.vue`
- Create: `frontend/src/workspace/WorkspaceApp.vue`
- Create: `frontend/src/identity/AuthenticationLanding.vue`
- Modify: `frontend/src/style.css`

- [ ] **Step 1: Preserve the existing workspace lifecycle in `WorkspaceApp.vue`**

Move the existing mounted fetches, realtime connection and workspace template unchanged. It is instantiated only after a current session is confirmed, so no protected request occurs for a guest.

- [ ] **Step 2: Make `App.vue` a session state machine**

Render a loading state initially; render `AuthenticationLanding` after `loadCurrentSession` returns `null`; render `WorkspaceApp` only for an authenticated session. A non-401 session error gets a retry control, not a false anonymous state.

- [ ] **Step 3: Implement the landing form**

Provide switchable `Войти` and `Создать аккаунт` forms with login and password fields. Registration calls register then login; a successful login emits `authenticated` so the root gate reloads the current session. Disable controls while pending and show returned failures in an alert.

- [ ] **Step 4: Add focused visual styles**

Use local class names for a responsive, keyboard-accessible full-screen landing page. Do not alter media, runtime URLs or protected API ACLs.

- [ ] **Step 5: Run the frontend build and tests**

Run:

```powershell
npm test
npm run build
```

Expected: Vitest passes and Vite produces a production bundle with no TypeScript errors.

### Task 3: Deploy and smoke-test only after local validation

**Files:**
- No additional source files.

- [ ] **Step 1: Build the approved remote compose service with the validated frontend**

Run the project deployment flow without outputting `.env` or secrets. The API and proxy must remain private except for the approved public web ports.

- [ ] **Step 2: Verify guest and authenticated boundaries**

Confirm `https://v.bootybay.ru/` responds with the landing bundle, `GET /api/v1/auth/session` is 401 before login, and the browser landing view does not issue `/channels` or realtime requests until login. Then manually register/login a disposable test account only if the owner supplies an approved test credential policy.

- [ ] **Step 3: Inspect scoped changes**

Run `git diff --check` for only the files in Tasks 1-2 and `git status --short`; do not stage unrelated worktree changes.
