# Attachment volume ownership

Supported topology: exactly one API writer per attachment volume. Reservations
are process-local, so overlapping APIs cannot safely budget the same free space.
The API acquires an exclusive nonblocking OS lock before opening DB/workers and
holds it until its HTTP server and workers have shut down. A second API fails
startup without serving requests. Linux uses flock; Windows development uses
LockFileEx. OS exit releases ownership, including crashes.

Keep `.api-writer.lock` in the volume. Never delete or replace it while an API
could be running: a second inode would evade the existing lock. Do not mount the
same data through different remote filesystems; distributed writers require an
ADR and a different reservation/locking design.

Compose explicitly supports one replica and stop-first update/rollback. Guarded
rollout and compatible rollback must stop the old API before starting the next;
do not scale API, use start-first updates or bypass a failed startup/readiness.
Existing volume/history are retained; no backup or snapshot flow is added.

Preflight: run the native topology check and confirm exactly one live API for
the deployment. The process lock is the final startup guard, not permission to
skip release headroom, migration compatibility or media-drain checks.
The signed installer and rollback path inspect expanded Compose JSON and the
running API count before invoking the guarded rollout. Two replicas or a
start-first order fail before mutation. Previously signed Compose files retain
their native one-replica/stop-first defaults; no old signed file is rewritten.

`go test ./internal/storage/acquire_writer_lock` exercises same-process exclusion,
independent-process exclusion, crash release and owner handover. Integration QA
also attempts a second actual API and requires its bounded startup rejection.
