package adminpostgres

import (
	"context"
	"errors"
	"sync"
	"testing"

	"voice-platform/backend/internal/identity/admin_account"
)

func TestConcurrentAdministratorDemotionKeepsOneActiveAdministrator(t *testing.T) {
	fixture := newAdminFixture(t)
	repository := New(NewPoolDatabase(fixture.pool))
	results := raceAdminUpdates(t, repository, fixture, false)
	assertOneAdministratorSurvives(t, fixture, results)
}

func TestConcurrentAdministratorBlockingKeepsOneActiveAndRevokesOnlyBlockedSession(t *testing.T) {
	fixture := newAdminFixture(t)
	for index, id := range []string{fixture.first, fixture.second} {
		if _, err := fixture.pool.Exec(context.Background(), `INSERT INTO sessions (token_digest,user_id) VALUES (decode(repeat($1,64),'hex'),$2)`, string(rune('a'+index)), id); err != nil {
			t.Fatal(err)
		}
	}
	repository := New(NewPoolDatabase(fixture.pool))
	results := raceAdminUpdates(t, repository, fixture, true)
	assertOneAdministratorSurvives(t, fixture, results)
	var activeSessions, blockedSessions int
	if err := fixture.pool.QueryRow(context.Background(), `SELECT count(*) FILTER (WHERE u.blocked_at IS NULL AND s.revoked_at IS NULL), count(*) FILTER (WHERE u.blocked_at IS NOT NULL AND s.revoked_at IS NOT NULL) FROM sessions s JOIN users u ON u.id=s.user_id`).Scan(&activeSessions, &blockedSessions); err != nil {
		t.Fatal(err)
	}
	if activeSessions != 1 || blockedSessions != 1 {
		t.Fatalf("session state active=%d revoked=%d, want 1 each", activeSessions, blockedSessions)
	}
}

func raceAdminUpdates(t *testing.T, repository Repository, fixture adminFixture, blocked bool) [2]error {
	t.Helper()
	start := make(chan struct{})
	ids := [2]string{fixture.first, fixture.second}
	var results [2]error
	var group sync.WaitGroup
	for index, id := range ids {
		group.Add(1)
		go func(index int, id string) {
			defer group.Done()
			<-start
			_, results[index] = repository.Update(context.Background(), adminaccount.Input{ActorID: id, AccountID: id, Role: adminaccount.RoleMember, Blocked: blocked})
		}(index, id)
	}
	close(start)
	group.Wait()
	return results
}

func assertOneAdministratorSurvives(t *testing.T, fixture adminFixture, results [2]error) {
	t.Helper()
	success, denied := 0, 0
	for _, err := range results {
		switch {
		case err == nil:
			success++
		case errors.Is(err, adminaccount.ErrUpdateDenied):
			denied++
		default:
			t.Fatalf("unexpected concurrent update error: %v", err)
		}
	}
	if success != 1 || denied != 1 {
		t.Fatalf("outcomes success=%d denied=%d, want 1 each", success, denied)
	}
	var active int
	if err := fixture.pool.QueryRow(context.Background(), `SELECT count(*) FROM users WHERE role='ADMINISTRATOR' AND blocked_at IS NULL`).Scan(&active); err != nil {
		t.Fatal(err)
	}
	if active != 1 {
		t.Fatalf("active administrators=%d, want 1", active)
	}
	var audits int
	if err := fixture.pool.QueryRow(context.Background(), `SELECT count(*) FROM audit_events WHERE event_type='ACCOUNT_ADMIN_STATE_UPDATED'`).Scan(&audits); err != nil {
		t.Fatal(err)
	}
	if audits != 1 {
		t.Fatalf("admin update audit events=%d, want 1", audits)
	}
}
