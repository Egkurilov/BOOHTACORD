package acquirevoiceleasepostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	acquirevoicelease "voice-platform/backend/internal/voice/acquire_voice_lease"
)

func TestRepositoryIssuesLeaseForActiveSessionAndVoiceChannel(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	transaction := &fakeTransaction{rows: []fakeRow{{values: []any{[]byte("session")}}, {values: []any{"voice-1"}}, {err: pgx.ErrNoRows}, {values: []any{"lease-1", "voice-1"}}}}
	result, err := New(&fakeDatabase{transaction: transaction}).Acquire(context.Background(), acquirevoicelease.Request{ID: "lease-1", Input: acquirevoicelease.Input{ActorID: "user-1", ChannelID: "voice-1", SessionDigest: digest}})
	if err != nil || !transaction.topologyLocked || !transaction.userLocked || !transaction.committed || transaction.rolledBack || result != (acquirevoicelease.Result{ID: "lease-1", ChannelID: "voice-1"}) {
		t.Fatalf("error = %v, transaction = %#v, result = %#v", err, transaction, result)
	}
	if !strings.Contains(transaction.statements[0], "revoked_at IS NULL") || !strings.Contains(transaction.statements[1], "admission_closed_at IS NULL") || !strings.Contains(transaction.statements[3], "session_token_digest") {
		t.Fatalf("statements = %#v", transaction.statements)
	}
}

func TestRepositoryReturnsExistingLeaseUntilExplicitTransfer(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	transaction := &fakeTransaction{rows: []fakeRow{{values: []any{[]byte("session")}}, {values: []any{"voice-new"}}, {values: []any{"lease-old", "voice-old"}}}}
	result, err := New(&fakeDatabase{transaction: transaction}).Acquire(context.Background(), acquirevoicelease.Request{ID: "lease-new", Input: acquirevoicelease.Input{ActorID: "user-1", ChannelID: "voice-new", SessionDigest: digest}})
	if !errors.Is(err, acquirevoicelease.ErrActiveLease) || result.ExistingChannelID != "voice-old" || !transaction.rolledBack || transaction.committed {
		t.Fatalf("error = %v, transaction = %#v, result = %#v", err, transaction, result)
	}
}

func TestRepositoryTransferRevokesOldLeaseBeforeIssuingNewOne(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	transaction := &fakeTransaction{rows: []fakeRow{{values: []any{[]byte("session")}}, {values: []any{"voice-new"}}, {values: []any{"lease-old", "voice-old"}}, {values: []any{"lease-old"}}, {values: []any{"lease-new", "voice-new"}}}}
	result, err := New(&fakeDatabase{transaction: transaction}).Acquire(context.Background(), acquirevoicelease.Request{ID: "lease-new", Input: acquirevoicelease.Input{ActorID: "user-1", ChannelID: "voice-new", SessionDigest: digest, Transfer: true}})
	if err != nil || !result.Transferred || !strings.Contains(transaction.statements[3], "revocation_reason = 'TRANSFER'") || !strings.Contains(transaction.statements[3], "INSERT INTO voice_sfu_revocations") || !strings.Contains(transaction.statements[4], "INSERT INTO voice_leases") {
		t.Fatalf("error = %v, statements = %#v, result = %#v", err, transaction.statements, result)
	}
}

type fakeDatabase struct{ transaction *fakeTransaction }

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	rows                                              []fakeRow
	statements                                        []string
	topologyLocked, userLocked, committed, rolledBack bool
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.topologyLocked = true
	return nil
}
func (transaction *fakeTransaction) LockUser(context.Context, string) error {
	transaction.userLocked = true
	return nil
}
func (transaction *fakeTransaction) QueryRow(_ context.Context, statement string, _ ...any) Row {
	transaction.statements = append(transaction.statements, statement)
	row := transaction.rows[0]
	transaction.rows = transaction.rows[1:]
	return row
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
		case *[]byte:
			*destination = value.([]byte)
		}
	}
	return nil
}
