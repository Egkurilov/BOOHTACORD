# Guild identity and people quick jump (#78)

Route: `small_direct`, bounded search navigation and notification title leaves.
Owner approved on 2026-10-09: retain BOOHTACORD logo; show configured one-guild
name in auth/header/title/notifications; add accessible guild people without Join.
Preserve TEXT/current DM navigation, message search state, IME and focus return.
Server candidate and DM creation ACL remain authoritative; no global discovery.

- Write focused people/dedup/pagination/disposal and title tests first.
- Load existing authorized DM candidates lazily and page explicitly; combine with
  existing DM targets without duplicates or self; recheck through existing DM API.
- Wire actual QuickJumpPanel and keep the currently open voice connection intact.
- Pass current public guild name into Web/native generic notification title;
  preserve application identity, generic DM body and account admission guards.
- Run nearest/full Web, native notification tests and actual Chromium scenarios.
- Record remaining physical OS notification/screen-reader acceptance in QA.

Limits: files target100/hard120, one trigger family per child leaf, target8/hard16.
Stop: integrated source, native checks and truthful evidence; no device claims.
