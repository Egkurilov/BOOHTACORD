package recoverlastadministratoraccesspostgres

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/recover_last_administrator_access"
)

func TestSoleAdministratorRecoveryWaitsForConcurrentPromotion(t *testing.T) {
	pool := newRecoveryPool(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	ownerID, memberID := uuid.NewString(), uuid.NewString()
	for _, fixture := range []struct {
		statement string
		id        string
	}{
		{`INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'owner', 'Owner', 'old-hash', 'ADMINISTRATOR')`, ownerID},
		{`INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'member', 'Member', 'member-hash', 'MEMBER')`, memberID},
	} {
		if _, err := pool.Exec(ctx, fixture.statement, fixture.id); err != nil {
			t.Fatal(err)
		}
	}
	promotion, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer promotion.Rollback(ctx)
	if _, err := promotion.Exec(ctx, `SELECT pg_advisory_xact_lock(441903816)`); err != nil {
		t.Fatal(err)
	}
	if _, err := promotion.Exec(ctx, `UPDATE users SET role='ADMINISTRATOR' WHERE id=$1`, memberID); err != nil {
		t.Fatal(err)
	}
	result := make(chan error, 1)
	go func() { result <- New(NewPoolDatabase(pool)).RecoverSoleActiveAdministrator(ctx, "owner", "new-hash") }()
	select {
	case err := <-result:
		_ = promotion.Commit(ctx)
		t.Fatalf("recovery finished before role change committed: %v", err)
	case <-time.After(750 * time.Millisecond):
	}
	if err := promotion.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	if err := <-result; !errors.Is(err, recoverlastadministratoraccess.ErrRecoveryUnavailable) {
		t.Fatalf("recovery after promotion = %v, want unavailable", err)
	}
	var hash string
	var audits int
	if err := pool.QueryRow(ctx, `SELECT password_hash FROM users WHERE id=$1`, ownerID).Scan(&hash); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE event_type='LAST_ADMINISTRATOR_ACCESS_RECOVERED'`).Scan(&audits); err != nil {
		t.Fatal(err)
	}
	if hash != "old-hash" || audits != 0 {
		t.Fatalf("denied recovery changed hash=%t or wrote audits=%d", hash != "old-hash", audits)
	}
}
