package renamepostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/rename_channel"
)

func TestRepositoryRenamesActiveChannelAtomically(t *testing.T) {
	tx := &fakeTransaction{row: fakeRow{values: []any{"channel-1", "Игры", int64(3)}}}
	input := renamechannel.Input{ActorID: "admin-1", ChannelID: "channel-1", Name: "Игры", ExpectedRevision: 2}
	result, err := New(&fakeDatabase{tx: tx}).Rename(context.Background(), input)
	if err != nil || result != (renamechannel.Result{ID: "channel-1", Name: "Игры", Revision: 3}) {
		t.Fatalf("result = %#v, error = %v", result, err)
	}
	if !tx.locked || !tx.committed || tx.rolledBack || tx.lockKey != topologyLockKey {
		t.Fatalf("transaction = %#v", tx)
	}
	if len(tx.arguments) != 4 || tx.arguments[0] != int64(2) || tx.arguments[1] != "channel-1" || tx.arguments[2] != "Игры" || tx.arguments[3] != "admin-1" {
		t.Fatalf("arguments = %#v", tx.arguments)
	}
	for _, fragment := range []string{
		"UPDATE channels", "SET name = $3", "archived_at IS NULL", "revision = $1", "revision = revision + 1", "INSERT INTO audit_events", "CHANNEL_RENAMED", "channel_id",
	} {
		if !strings.Contains(tx.statement, fragment) {
			t.Fatalf("SQL missing %q: %s", fragment, tx.statement)
		}
	}
	if strings.Contains(tx.statement, "SET kind") || strings.Contains(tx.statement, "kind = $3") {
		t.Fatalf("rename must not change channel kind: %s", tx.statement)
	}
}

func TestRepositoryMapsMissingArchivedOrStaleChannelToConflict(t *testing.T) {
	tx := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{tx: tx}).Rename(context.Background(), renamechannel.Input{})
	if !errors.Is(err, renamechannel.ErrRevisionConflict) || !tx.rolledBack || tx.committed {
		t.Fatalf("error = %v, transaction = %#v", err, tx)
	}
}

func TestRepositoryDoesNotReturnSuccessAfterCommitFailure(t *testing.T) {
	tx := &fakeTransaction{row: fakeRow{values: []any{"channel-1", "Игры", int64(3)}}, commitErr: errors.New("commit failed")}
	_, err := New(&fakeDatabase{tx: tx}).Rename(context.Background(), renamechannel.Input{})
	if err == nil || !tx.rolledBack {
		t.Fatalf("error = %v, transaction = %#v", err, tx)
	}
}

type fakeDatabase struct{ tx *fakeTransaction }

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) { return database.tx, nil }

type fakeTransaction struct {
	row        fakeRow
	lockKey    int64
	locked     bool
	committed  bool
	rolledBack bool
	commitErr  error
	statement  string
	arguments  []any
}

func (tx *fakeTransaction) Lock(_ context.Context, key int64) error {
	tx.lockKey, tx.locked = key, true
	return nil
}
func (tx *fakeTransaction) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	tx.statement, tx.arguments = statement, arguments
	return tx.row
}
func (tx *fakeTransaction) Commit(context.Context) error {
	tx.committed = true
	return tx.commitErr
}
func (tx *fakeTransaction) Rollback(context.Context) error {
	tx.rolledBack = true
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
		case *int64:
			*destination = value.(int64)
		}
	}
	return nil
}
