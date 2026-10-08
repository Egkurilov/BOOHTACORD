package adminpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"go.opentelemetry.io/otel/trace"
	"voice-platform/backend/internal/identity/admin_account"
	causal "voice-platform/backend/internal/observability/causal_reference"
)

func TestRepositoryLocksAndAtomicallyProtectsLastActiveAdministrator(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"target", "MEMBER", true}}}
	repository := New(&fakeDatabase{transaction: transaction})
	account, err := repository.Update(context.Background(), adminaccount.Input{ActorID: "actor", AccountID: "target", Role: adminaccount.RoleMember, Blocked: true})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if !transaction.locked || !transaction.userLocked || !transaction.committed || transaction.rolledBack || account != (adminaccount.Account{ID: "target", Role: adminaccount.RoleMember, Blocked: true}) {
		t.Fatalf("transaction = %#v, account = %#v", transaction, account)
	}
	if transaction.arguments[0] != "target" || transaction.arguments[1] != "MEMBER" || transaction.arguments[2] != true || transaction.arguments[3] != "actor" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"NOT EXISTS", "UPDATE sessions", "UPDATE voice_leases", "revocation_reason = 'BANNED'", "INSERT INTO voice_sfu_revocations", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryPersistsBoundedCauseWithRevocationOutboxTransaction(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"target", "MEMBER", true}}}
	ctx := trace.ContextWithSpanContext(context.Background(), trace.NewSpanContext(trace.SpanContextConfig{
		TraceID: trace.TraceID{1}, SpanID: trace.SpanID{2}, TraceFlags: trace.FlagsSampled,
	}))
	_, err := New(&fakeDatabase{transaction: transaction}).Update(ctx, adminaccount.Input{ActorID: "actor", AccountID: "target", Role: adminaccount.RoleMember, Blocked: true})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if !strings.Contains(transaction.statement, "INSERT INTO voice_sfu_revocations (lease_id, channel_id, trace_cause)") {
		t.Fatal("revocation outbox does not persist its originating cause")
	}
	if len(transaction.arguments) != 6 {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	stored, ok := transaction.arguments[5].([]byte)
	if !ok || causal.Decode(stored) != causal.From(ctx) {
		t.Fatal("transaction did not store the bounded originating cause")
	}
}

func TestRepositoryMapsLastAdminOrMissingTargetToDenied(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Update(context.Background(), adminaccount.Input{})
	if !errors.Is(err, adminaccount.ErrUpdateDenied) || !transaction.rolledBack {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

type fakeDatabase struct {
	transaction *fakeTransaction
}

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	row        fakeRow
	locked     bool
	userLocked bool
	committed  bool
	rolledBack bool
	statement  string
	arguments  []any
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.locked = true
	return nil
}

func (transaction *fakeTransaction) LockUser(context.Context, string) error {
	transaction.userLocked = true
	return nil
}

func (transaction *fakeTransaction) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	transaction.statement = statement
	transaction.arguments = arguments
	return transaction.row
}

func (transaction *fakeTransaction) Commit(context.Context) error {
	transaction.committed = true
	return nil
}

func (transaction *fakeTransaction) Rollback(context.Context) error {
	transaction.rolledBack = true
	return nil
}

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	for index, value := range row.values {
		switch destination := destinations[index].(type) {
		case *string:
			*destination = value.(string)
		case *bool:
			*destination = value.(bool)
		}
	}
	return nil
}
