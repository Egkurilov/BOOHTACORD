# Administrator Topology Web Release Plan

**Goal:** Release the locally validated administrator topology UI to the existing production web service without owner authentication, database mutation, migration, or media activity.

**Architecture:** Copy the bounded frontend build inputs to a server-local staging directory, build one uniquely tagged non-`latest` web image, update only `WEB_IMAGE` in the protected deployment environment, and recreate only the `web` service. API, PostgreSQL, LiveKit, proxy configuration, volumes, and the owner session remain unchanged.

---

### Task 1: Validate the release input and replace only the web container

- [x] **Step 1: Verify SSH connectivity, compose service shape, and current web container state without reading `.env`.**
- [x] **Step 2: Transfer only frontend build inputs to a new server-local staging directory.**
- [x] **Step 3: Build a uniquely tagged web image, atomically select it as `WEB_IMAGE`, and recreate only `web`.**

### Task 2: Verify public guest boundaries and record the release result

- [x] **Step 1: Confirm HTTPS landing, public health, and unauthenticated session response are all HTTP 200.**
- [x] **Step 2: Confirm the web container is running the new non-`latest` tag; do not authenticate, create topology, or touch POC evidence.**
