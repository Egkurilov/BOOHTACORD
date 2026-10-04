package descriptionpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/update_description"
)

func TestUpdateDescriptionLocksRevisesAndAudits(t *testing.T) {
	tx := &fakeTransaction{row: fakeRow{values: []any{"channel-1", "Общение", int64(3)}}}
	input := updatedescription.Input{ActorID: "admin-1", ChannelID: "channel-1", Description: "Общение", ExpectedRevision: 2}
	result, err := New(&fakeDatabase{tx}).Update(context.Background(), input)
	if err != nil || result != (updatedescription.Result{ID: "channel-1", Description: "Общение", Revision: 3}) {
		t.Fatalf("result=%#v err=%v", result, err)
	}
	if !tx.locked || tx.lockKey != topologyLockKey || !tx.committed || tx.rolledBack {
		t.Fatalf("tx=%#v", tx)
	}
	if len(tx.arguments) != 4 || tx.arguments[0] != int64(2) || tx.arguments[1] != "channel-1" || tx.arguments[2] != "Общение" || tx.arguments[3] != "admin-1" {
		t.Fatalf("arguments=%#v", tx.arguments)
	}
	for _, fragment := range []string{"SET description = $3", "archived_at IS NULL", "revision = revision + 1", "INSERT INTO audit_events", "CHANNEL_DESCRIPTION_UPDATED"} {
		if !strings.Contains(tx.statement, fragment) {
			t.Fatalf("missing %q in SQL", fragment)
		}
	}
	if strings.Contains(tx.statement, "SET name") || strings.Contains(tx.statement, "SET kind") {
		t.Fatal("description update changed channel identity")
	}
}

func TestUpdateDescriptionMapsConflictAndCommitFailure(t *testing.T) {
	tx := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{tx}).Update(context.Background(), updatedescription.Input{})
	if !errors.Is(err, updatedescription.ErrRevisionConflict) || !tx.rolledBack {
		t.Fatalf("err=%v tx=%#v", err, tx)
	}
	tx = &fakeTransaction{row: fakeRow{values: []any{"channel-1", "", int64(3)}}, commitErr: errors.New("commit failed")}
	_, err = New(&fakeDatabase{tx}).Update(context.Background(), updatedescription.Input{})
	if err == nil || !tx.rolledBack {
		t.Fatalf("err=%v tx=%#v", err, tx)
	}
}

type fakeDatabase struct{ tx *fakeTransaction }

func (db *fakeDatabase) Begin(context.Context) (Transaction, error) { return db.tx, nil }

type fakeTransaction struct {
	row                           fakeRow
	lockKey                       int64
	locked, committed, rolledBack bool
	commitErr                     error
	statement                     string
	arguments                     []any
}

func (tx *fakeTransaction) Lock(_ context.Context, key int64) error {
	tx.lockKey, tx.locked = key, true
	return nil
}
func (tx *fakeTransaction) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	tx.statement, tx.arguments = statement, arguments
	return tx.row
}
func (tx *fakeTransaction) Commit(context.Context) error   { tx.committed = true; return tx.commitErr }
func (tx *fakeTransaction) Rollback(context.Context) error { tx.rolledBack = true; return nil }

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	for index, value := range row.values {
		switch target := destinations[index].(type) {
		case *string:
			*target = value.(string)
		case *int64:
			*target = value.(int64)
		}
	}
	return nil
}
