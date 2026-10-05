# System welcome clients — #101

Status: implementation and automated checks PASS; physical live-client gate NOT_RUN.

## Preserved server behavior

The existing registration transaction creates the account and optional welcome
together. A partial unique index permits one SYSTEM_WELCOME per account. History,
search and deletion keep the explicit kind; administrator deletion is permitted,
user editing/deletion, replies and attachments are denied by the server.
Archive cleanup disables the unavailable target atomically. Publication is a
post-commit hint; its failure cannot undo a committed registration.

## Client behavior

- Both administrator editors offer active TEXT targets and an explicit disabled
  option. An unavailable selection cannot be submitted; VOICE is omitted.
- Web/Flutter preserve SYSTEM_WELCOME in history, unified search and context.
  Older USER-only server responses retain their compatibility defaults.
- Distinct system rows resolve the recipient by stable account ID and the current
  author directory/member list. They do not join ordinary author groups.
- System rows have no reply/edit/file actions. Only the administrator sees delete;
  the existing deletion confirmation and server ACL remain in effect.
- Native realtime refreshes members when a newly registered welcome author is
  absent from the loaded member list. Unknown names use a neutral fallback.
- Announcements/desktop notifications say “Новый участник в гильдии.” and contain
  neither the participant name nor the welcome body. Background classification
  uses protected addressed history; disabled notifications cause no extra lookup.
- DTOs were physically moved into Flutter message/search leaf capabilities;
  compatibility exports preserve existing imports and copy/deletion semantics.

## Checks

Go/PostgreSQL registration, message ACL, settings/archive and outcome tests PASS.
They cover enabled/disabled/unavailable, insertion rollback, immutable messages,
unique constraints and publication failure after commit.
Web system-kind/grouping/announcement tests PASS. Six actual-component browser
checks PASS, including participant rename, deleted state and missing edit/reply.
Flutter model/controller/widget checks PASS; complete application suite 609 PASS.
Contracts and local dependency boundaries PASS.

## Limits

Browser APIs in layout acceptance are mocks; they are not a two-device production
registration. Real PostgreSQL/HTTP/OTLP evidence is separate. Physical Android and
Windows realtime appearance/reconnect NOT_RUN. No production accounts were created.
