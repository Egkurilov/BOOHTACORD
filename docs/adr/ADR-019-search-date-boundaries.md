# ADR-019 — Search date boundaries

Status: accepted engineering decision, 2026-10-08, IMP-16 / issue #76.

REQ-SEARCH-01 requires existing channel/own-DM search, server ACL, and cursor paging. IMP-16 adds date ranges but does not specify a zone or boundary rule. No approved requirement mandates a different rule.

The existing `/api/v1/search/messages` endpoint accepts optional `created_from` and `created_before` RFC3339 instants with explicit `Z` or numeric offset. Both normalize to UTC; start is inclusive and end exclusive. When both are present, start must precede end. Empty, duplicate, malformed, offset-free, and reversed/equal bounds return `VALIDATION_FAILED`. Each cursor request resends unchanged filters; cursor order remains `(created_at, id, kind)` descending. Precision is at most microseconds, matching PostgreSQL timestamps.

Browser date-only controls use the user's local calendar. “С даты” maps to local midnight on the selected first day; “По дату включительно” maps to local midnight on the following calendar day. Calendar arithmetic preserves 23/25-hour daylight-saving days; adding 24 hours is prohibited. Invalid or nonexistent local dates are rejected. Filters survive panel reopening and reset on logout. The displayed helper identifies the local timezone interpretation.

The same predicates apply inside both existing SQL arms before paging. Date/author/attachment filters never widen channel visibility or DM membership, revive deleted messages or hidden attachments, or search file contents. Existing partial GIN indexes remain usable; changing the search system or adding indexes without observed query-plan need is unnecessary.

Verification covers explicit-offset normalization, start/end boundaries, equal timestamp mixed-source paging, local DST calendar mapping, filter persistence/logout, deleted/hidden/private data exclusions, and production-shaped SQL plans on disposable PostgreSQL. Physical/browser acceptance remains separately recorded rather than inferred from compilation.
