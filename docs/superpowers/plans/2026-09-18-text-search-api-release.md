# Text Search API Release Plan

**Goal:** Release the validated text-channel search API and its idempotent PostgreSQL index migration without owner login, channel creation, media activity, or a proxy/web restart.

**Architecture:** Copy only the changed API route, new search leaf, and migration into a unique server-local staging directory. Build a non-`latest` API image, select it as `API_IMAGE`, run `migrate` before recreating only `api`, then verify public health and the unauthenticated route boundary. Existing PostgreSQL data, LiveKit, web image, proxy, volumes, and session state are not changed.

---

### Task 1: Replace the API only after preflight

- [x] **Step 1: Verify SSH connectivity and the current API/web container tags without reading or printing `.env`.**
- [x] **Step 2: Transfer only `chat_routes.go`, `search_text_messages`, and migration `0026` to a new server-local staging directory.**
- [x] **Step 3: Build a uniquely tagged API image, set only `API_IMAGE`, run the migration, and recreate only `api`.**

### Task 2: Verify the live non-credentialed boundary

- [x] **Step 1: Confirm public health is HTTP 200 and unauthenticated text-search is HTTP 401.**
- [x] **Step 2: Confirm the API container is running the new non-`latest` tag and staging data is removed. Do not authenticate or create POC evidence.**
