# Readonly TEXT archives implementation plan

**Goal:** Complete IMP-05 with an explicit readable archive mode while preserving approved inaccessible DELETE archives and VOICE behavior.

**Architecture:** Add `readonly_archive` on TEXT channels; existing deletion keeps its current inaccessible state. Separate authenticated archive discovery/history/search/file routes authorize only flagged archived TEXT. Separate administrator archive/restore mutations use the existing topology lock/revision, preserve IDs/history, and publish topology updates. Existing active routes and all writes retain archived denial.

**Tech Stack:** Go/pgx/PostgreSQL, Vue/TypeScript, existing secure session middleware and private file store.

Operating brief: split_first; leaf families archive_readonly_text, restore_readonly_text, list_archived_text, existing list_text_messages/search_messages/download_text_attachment, Web readonly_archive. All changed source <=120 lines; no root-wide search. Parent owns PG scheduling and remote integration.

- [x] Read archive/delete, history/search/file ACL and native composition edges; record approved delete preservation in ADR-021.
- [x] Write meaningful archive/restore unit tests and disposable-PG lifecycle/privacy/read tests before implementation.
- [x] Add migration `0050_add_readonly_text_archive.sql` with false default and TEXT/archived consistency constraint; no existing archived row becomes readable.
- [x] Implement independent archive/restore service+SQL leaves with administrator and blocked-account guards, same channel ID, expected topology revision, welcome-channel clearing on archive, audit and atomic rollback.
- [x] Implement separate archive list with bounded cursor paging and metadata; never list deleted archive or VOICE.
- [x] Add internal archive read modes/adapters to existing history/search/download leaves. Public live endpoints do not parse/accept the internal flag. Keep deleted messages/hidden attachments and DM exclusions unchanged.
- [x] Register secure archive routes through a <=120-line composition leaf and one native runtime import/call, preserving existing channel routes.
- [x] Document new routes/schemas in OpenAPI and ADR-021; run parity/traceability validation.
- [x] Implement browser Archive tab, list/readonly history/search/files and explicit admin archive/restore confirmation/actions in responsibility-focused components; preserve voice lifecycle and normal composer.
- [x] Run focused source/Web checks, real PostgreSQL ACL/lifecycle/old-URL negative checks, real browser component behavior; then appropriate full Web build/tests.
- [x] Save source/runtime evidence with exact checks and honest remaining application/device QA; inspect status/file sizes, stage exact files, and commit locally. No push/merge/issue mutation.
