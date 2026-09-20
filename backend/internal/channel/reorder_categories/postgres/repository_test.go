package reorderpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/reorder_categories"
)

func TestRepositoryDefersUniquePositionsAndAdvancesMatchingRevision(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{revision: 3}}
	repository := New(&fakeDatabase{transaction: transaction})
	result, err := repository.Reorder(context.Background(), reordercategories.Input{ActorID: "admin-1", ExpectedRevision: 2, IDs: []string{"category-2", "category-1"}})
	if err != nil {
		t.Fatalf("Reorder() error = %v", err)
	}
	if !transaction.locked || !transaction.positionsDeferred || !transaction.committed || transaction.rolledBack || result.Revision != 3 {
		t.Fatalf("transaction = %#v, result = %#v", transaction, result)
	}
	if transaction.arguments[0] != int64(2) || transaction.arguments[2] != "admin-1" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"WITH ORDINALITY", "UPDATE categories", "channel_topology_state", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryMapsMismatchToRevisionConflict(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Reorder(context.Background(), reordercategories.Input{})
	if !errors.Is(err, reordercategories.ErrRevisionConflict) || !transaction.rolledBack {
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
	row               fakeRow
	locked            bool
	positionsDeferred bool
	committed         bool
	rolledBack        bool
	statement         string
	arguments         []any
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.locked = true
	return nil
}

func (transaction *fakeTransaction) DeferPositions(context.Context) error {
	transaction.positionsDeferred = true
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
	revision int64
	err      error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	*destinations[0].(*int64) = row.revision
	return nil
}
