# Operator attachment cleanup

Run the existing operator binaries with the approved private database and absolute
`ATTACHMENTS_DIRECTORY`. Application administrator rights do not grant shell access.

```text
cleanup-stale-staging --dry-run
cleanup-unattached-attachments --dry-run
cleanup-hidden-attachments --dry-run
```

Dry-run emits aggregate eligible count/bytes, oldest retry age and bounded skip
reasons. It opens a read-only database transaction and writes no rows, audit events,
claim sequence or files. Database bytes describe metadata candidates; they are
not a claim about physical bytes reclaimed after previous partial unlink failures.
Staging bytes use current filesystem sizes. Names and storage keys are omitted.

Execution uses the existing command names without `--dry-run`, optionally
`--limit=1..100`. HIDDEN/UNATTACHED claim fairness and retry timing remain intact.
Immediately before unlink, execution locks the attachment row and rechecks the
claim/state, exact storage key and links, holding the lock through filesystem and
database finalization. A new live link retains its file. Partial unlink/DB failure
remains retryable; an already missing file is handled idempotently.

Staging execution defaults to at most 100 old regular `upload-*.part` files and
rechecks age/type immediately before unlink. Unexpected names, symlinks, directories
and recent files are retained. Repeat bounded runs until the report is empty.

Explicit orphan recovery retains its separate `--orphan-key` operator mode and
cannot be combined with `--dry-run`. Published history has no TTL. No backup or
application-admin filesystem deletion endpoint is introduced.
