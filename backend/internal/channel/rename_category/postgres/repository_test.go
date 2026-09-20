package renamepostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/rename_category"
)

func TestRepositoryChangesNameOnlyForExpectedRevision(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"category-1", "Игры", int64(3)}}}
	result, err := New(&fakeDatabase{transaction: transaction}).Rename(context.Background(), renamecategory.Input{ActorID: "admin-1", CategoryID: "category-1", Name: "Игры", ExpectedRevision: 2})
	if err != nil {
		t.Fatalf("Rename() error = %v", err)
	}
	if !transaction.locked || !transaction.committed || transaction.rolledBack || result != (renamecategory.Result{ID: "category-1", Name: "Игры", Revision: 3}) {
		t.Fatalf("transaction = %#v, result = %#v", transaction, result)
	}
	if transaction.arguments[0] != int64(2) || transaction.arguments[1] != "category-1" || transaction.arguments[2] != "Игры" || transaction.arguments[3] != "admin-1" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"UPDATE categories", "channel_topology_state", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryMapsStaleOrAbsentCategoryToConflict(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Rename(context.Background(), renamecategory.Input{})
	if !errors.Is(err, renamecategory.ErrRevisionConflict) || !transaction.rolledBack {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

type fakeDatabase struct{ transaction *fakeTransaction }

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	row        fakeRow
	locked     bool
	committed  bool
	rolledBack bool
	statement  string
	arguments  []any
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.locked = true
	return nil
}
func (transaction *fakeTransaction) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	transaction.statement, transaction.arguments = statement, arguments
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
		case *int64:
			*destination = value.(int64)
		}
	}
	return nil
}
