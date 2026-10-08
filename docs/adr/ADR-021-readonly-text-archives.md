# ADR-021 — Explicit read-only TEXT archives

Status: accepted engineering design for requested IMP-05 / #92, 2026-10-08.

The approved REQ-CHANNEL-01 requires DELETE to confirm loss of history access and preserve data in an inaccessible archive. That behavior remains: existing archived channels have `readonly_archive=false` and remain inaccessible. The requested extension adds a separate explicit read-only archive action; it does not redefine DELETE or automatically expose old deleted channels.

All existing normal active TEXT readers may discover/read explicitly flagged TEXT archives through separate `/archives/text-channels` history/search/download routes. Those routes recheck active account, TEXT kind, archive timestamp and flag. Old active history/search/file URLs retain archived denial. Existing message deletion/hidden-file predicates and DM privacy continue. VOICE is never included or automatically archived/restored.

Only an active ADMINISTRATOR may explicitly archive for reading or restore through new management routes. Confirming read-only archive explains that history remains readable. Both mutations lock existing topology state, validate expected revision, update/audit atomically, and preserve channel ID/category/position/history/files. Restore only applies to read-only archives; inaccessible DELETE archives cannot be restored through this extension. Welcome-channel settings clear on archive and do not silently reinstate on restore.

While archived, every send/edit/upload/delete-message mutation remains forbidden through old URLs. In particular, send idempotency replay must recheck the active TEXT predicate before returning old results, preventing historical-response bypass. There is no composer or editing UI in archive view. The Archive tab is inside existing search UI so visiting it does not leave voice or replace the application lifecycle.

Cursor-paged archive discovery orders UUIDs ascending; history/search reuse existing stable tuple cursors with explicit archive scope. SQL/cookie ACL remains the authority; administrator UI visibility confers no resource access. Missing/blocked/deleted/VOICE cases disclose no history or files. Full application QA records exact SHA and browser/environment independently of focused tests.
