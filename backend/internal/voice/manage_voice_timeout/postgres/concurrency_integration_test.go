package managevoicetimeoutpostgres

import (
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"sync"
	"testing"
	"time"
	acquire "voice-platform/backend/internal/voice/acquire_voice_lease"
)

func TestConcurrentJoinAndTimeoutCannotLeaveAdmissibleLease(t *testing.T) {
	f := newFixture(t)
	for round := 0; round < 5; round++ {
		if _, err := f.repo.Clear(f.Context, f.input); err != nil {
			t.Fatal(err)
		}
		start := make(chan struct{})
		var group sync.WaitGroup
		var setErr, joinErr error
		group.Add(2)
		go func() { defer group.Done(); <-start; _, setErr = f.repo.Set(f.Context, f.input) }()
		go func() { defer group.Done(); <-start; _, joinErr = f.acquire() }()
		close(start)
		group.Wait()
		if setErr != nil || joinErr != nil && !errors.Is(joinErr, acquire.ErrVoiceTimeout) {
			t.Fatal(setErr, joinErr)
		}
		f.assertRevoked(t)
	}
}
func TestLegacyLeaseInsertWaitsForTimeoutAndFailsClosed(t *testing.T) {
	f := newFixture(t)
	tx, err := f.Pool.Begin(f.Context)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback(f.Context)
	if _, err = tx.Exec(f.Context, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, f.member); err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec(f.Context, `INSERT INTO voice_timeouts(user_id,updated_by,expires_at,reason_code)VALUES($1,$2,$3,$4)`, f.member, f.Admin, f.input.ExpiresAt, f.input.Reason); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() {
		_, err := f.Pool.Exec(f.Context, `INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest)VALUES($1,$2,$3,$4)`, uuid.NewString(), f.member, f.Voice, f.memberDigest[:])
		done <- err
	}()
	select {
	case err := <-done:
		t.Fatalf("legacy guard bypassed account lock: %v", err)
	case <-time.After(100 * time.Millisecond):
	}
	if err = tx.Commit(f.Context); err != nil {
		t.Fatal(err)
	}
	err = <-done
	var pgerr *pgconn.PgError
	if !errors.As(err, &pgerr) || pgerr.Code != "42501" {
		t.Fatalf("legacy guard error=%v", err)
	}
}
func TestCredentialAndSignalWaitForModerationLock(t *testing.T) {
	f := newFixture(t)
	tx, err := f.Pool.Begin(f.Context)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback(f.Context)
	if _, err = tx.Exec(f.Context, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, f.member); err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec(f.Context, `UPDATE voice_leases SET revoked_at=now(),revocation_reason='KICK' WHERE id=$1`, f.lease); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 2)
	go func() { done <- f.credential() }()
	go func() { done <- f.signal() }()
	select {
	case err := <-done:
		t.Fatalf("admission bypassed moderation lock: %v", err)
	case <-time.After(100 * time.Millisecond):
	}
	if err = tx.Commit(f.Context); err != nil {
		t.Fatal(err)
	}
	for range 2 {
		if err = <-done; err == nil {
			t.Fatal("stale read admitted media")
		}
	}
}
