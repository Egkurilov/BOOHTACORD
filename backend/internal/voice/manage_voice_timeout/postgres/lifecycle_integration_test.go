package managevoicetimeoutpostgres

import (
	"errors"
	"testing"
	"time"
	acquire "voice-platform/backend/internal/voice/acquire_voice_lease"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

func TestTimeoutRevokesAndDeniesEveryVoiceAdmission(t *testing.T) {
	f := newFixture(t)
	state, err := f.repo.Set(f.Context, f.input)
	if err != nil || !state.Active || state.RevokedLeases != 1 || !state.RevocationPending {
		t.Fatalf("state=%+v err=%v", state, err)
	}
	f.assertRevoked(t)
	if _, err = f.acquire(); !errors.Is(err, acquire.ErrVoiceTimeout) {
		t.Fatal(err)
	}
	again, err := f.repo.Set(f.Context, f.input)
	if err != nil || again.RevokedLeases != 0 || !again.Active {
		t.Fatalf("duplicate=%+v err=%v", again, err)
	}
	var audits, blocked, sessions int
	for _, q := range []struct {
		sql  string
		dest *int
	}{
		{`SELECT COUNT(*) FROM audit_events WHERE event_type='VOICE_TIMEOUT_SET'`, &audits},
		{`SELECT COUNT(*) FROM users WHERE blocked_at IS NOT NULL`, &blocked},
		{`SELECT COUNT(*) FROM sessions WHERE revoked_at IS NOT NULL`, &sessions},
	} {
		if err = f.Pool.QueryRow(f.Context, q.sql).Scan(q.dest); err != nil {
			t.Fatal(err)
		}
	}
	if audits != 1 || blocked != 0 || sessions != 0 {
		t.Fatalf("audits=%d blocked=%d sessions=%d", audits, blocked, sessions)
	}
}
func TestManualClearNeverRestoresLeaseOrCancelsRemoval(t *testing.T) {
	f := newFixture(t)
	if _, err := f.repo.Set(f.Context, f.input); err != nil {
		t.Fatal(err)
	}
	state, err := f.repo.Clear(f.Context, f.input)
	if err != nil || state.Active || !state.RevocationPending {
		t.Fatalf("state=%+v err=%v", state, err)
	}
	f.assertRevoked(t)
	if _, err = f.repo.Clear(f.Context, f.input); err != nil {
		t.Fatal(err)
	}
	var audits int
	if err = f.Pool.QueryRow(f.Context, `SELECT COUNT(*)FROM audit_events WHERE event_type='VOICE_TIMEOUT_CLEARED'`).Scan(&audits); err != nil || audits != 1 {
		t.Fatal(audits, err)
	}
	if _, err = f.acquire(); err != nil {
		t.Fatal("new manual Join blocked", err)
	}
}
func TestExpiryUsesDatabaseClockAndNeverReactivatesMedia(t *testing.T) {
	f := newFixture(t)
	if _, err := f.repo.Set(f.Context, f.input); err != nil {
		t.Fatal(err)
	}
	// Move only server state across boundary; no sleep or client-clock assumption.
	if _, err := f.Pool.Exec(f.Context, `UPDATE voice_timeouts SET expires_at=clock_timestamp()-interval '1 microsecond'`); err != nil {
		t.Fatal(err)
	}
	state, err := f.repo.Read(f.Context, f.input)
	if err != nil || state.Active || state.ExpiresAt != nil || state.Reason != "" {
		t.Fatalf("state=%+v err=%v", state, err)
	}
	f.assertRevoked(t)
	if _, err = f.acquire(); err != nil {
		t.Fatal("explicit new lease after expiry", err)
	}
}
func TestExpiryBoundsAndAuditFailureRollbackEverything(t *testing.T) {
	f := newFixture(t)
	for _, expiry := range []time.Time{time.Now().Add(-time.Minute), time.Now().Add(25 * time.Hour)} {
		in := f.input
		in.ExpiresAt = expiry
		if _, err := f.repo.Set(f.Context, in); !errors.Is(err, timeout.ErrInvalidInput) {
			t.Fatal(err)
		}
	}
	if _, err := f.Pool.Exec(f.Context, `ALTER TABLE audit_events ADD CONSTRAINT reject_timeout CHECK(event_type<>'VOICE_TIMEOUT_SET')`); err != nil {
		t.Fatal(err)
	}
	if _, err := f.repo.Set(f.Context, f.input); err == nil {
		t.Fatal("fault accepted")
	}
	var restrictions, queued, active int
	if err := f.Pool.QueryRow(f.Context, `SELECT (SELECT COUNT(*) FROM voice_timeouts),(SELECT COUNT(*) FROM voice_sfu_revocations),(SELECT COUNT(*) FROM voice_leases WHERE revoked_at IS NULL)`).Scan(&restrictions, &queued, &active); err != nil {
		t.Fatal(err)
	}
	if restrictions != 0 || queued != 0 || active != 1 {
		t.Fatal(restrictions, queued, active)
	}
}
