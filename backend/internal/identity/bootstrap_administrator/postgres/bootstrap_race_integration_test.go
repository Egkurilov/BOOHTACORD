package bootstrappostgres

import (
	"context"
	"errors"
	"sync"
	"testing"

	"github.com/google/uuid"
	"voice-platform/backend/internal/identity/bootstrap_administrator"
)

func TestConcurrentBootstrapCreatesOneAdministratorAndOneAuditEvent(t *testing.T) {
	pool := newBootstrapPool(t)
	repository := New(NewPoolDatabase(pool))
	start := make(chan struct{})
	var results [2]error
	var group sync.WaitGroup
	for index := range results {
		group.Add(1)
		go func(index int) {
			defer group.Done()
			<-start
			results[index] = repository.CreateInitial(context.Background(), bootstrapadministrator.Account{
				ID: uuid.NewString(), Login: []string{"firstadmin", "secondadmin"}[index], DisplayName: "Administrator",
				Role: bootstrapadministrator.RoleAdministrator, PasswordHash: "synthetic-test-hash",
			})
		}(index)
	}
	close(start)
	group.Wait()
	success, initialized := 0, 0
	for _, err := range results {
		switch {
		case err == nil:
			success++
		case errors.Is(err, bootstrapadministrator.ErrAlreadyInitialized):
			initialized++
		default:
			t.Fatalf("unexpected bootstrap result: %v", err)
		}
	}
	if success != 1 || initialized != 1 {
		t.Fatalf("outcomes success=%d initialized=%d, want 1 each", success, initialized)
	}
	var administrators, stateRows, audits int
	if err := pool.QueryRow(context.Background(), `SELECT count(*) FROM users WHERE role='ADMINISTRATOR'`).Scan(&administrators); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(context.Background(), `SELECT count(*) FROM bootstrap_state WHERE administrator_id IS NOT NULL`).Scan(&stateRows); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(context.Background(), `SELECT count(*) FROM audit_events WHERE event_type='INITIAL_ADMINISTRATOR_CREATED'`).Scan(&audits); err != nil {
		t.Fatal(err)
	}
	if administrators != 1 || stateRows != 1 || audits != 1 {
		t.Fatalf("administrators=%d state=%d audits=%d, want 1 each", administrators, stateRows, audits)
	}
}
