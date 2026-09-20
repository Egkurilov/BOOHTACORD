# Text Search Web Release Plan

**Goal:** Release the validated text-channel search UI to the existing web service without owner authentication, API/database mutation, POC activity, or proxy restart.

**Architecture:** Copy only frontend build inputs to a unique server-local staging directory, build one non-`latest` web image, update only `WEB_IMAGE`, and recreate only `web`. Confirm public guest boundaries after release; the protected search UI is not exercised without a legitimate session.

---

### Task 1: Replace only the web container

- [x] **Step 1: Verify SSH connectivity and existing web/API tags without reading `.env`.**
- [x] **Step 2: Transfer only frontend build inputs to a staging directory.**
- [x] **Step 3: Build a unique web tag, set only `WEB_IMAGE`, and recreate only `web`.**

### Task 2: Verify public boundaries

- [x] **Step 1: Confirm HTTPS landing, public health and anonymous session are HTTP 200.**
- [x] **Step 2: Confirm the new web tag runs and staging data is absent; do not authenticate or issue a real search.**
