package reorderpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/reorder_channels"
)

func TestRepositoryDefersOnlyChannelPositionConstraintAndRevises(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{revision: 4}}
	result, err := New(&fakeDatabase{transaction: transaction}).Reorder(context.Background(), reorderchannels.Input{ActorID: "admin-1", CategoryID: "category-1", ExpectedRevision: 3, IDs: []string{"channel-2", "channel-1"}})
	if err != nil {
		t.Fatalf("Reorder() error = %v", err)
	}
	if !transaction.locked || !transaction.positionsDeferred || !transaction.committed || transaction.rolledBack || result.Revision != 4 {
		t.Fatalf("transaction = %#v, result = %#v", transaction, result)
	}
	if transaction.arguments[0] != int64(3) || transaction.arguments[1] != "category-1" || transaction.arguments[3] != "admin-1" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"WITH ORDINALITY", "UPDATE channels", "channel.category_id = category.id", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryMapsWrongCategoryOrRevisionToConflict(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Reorder(context.Background(), reorderchannels.Input{})
	if !errors.Is(err, reorderchannels.ErrRevisionConflict) || !transaction.rolledBack {
		t.Fatalf("error = %v, transaction = %#v", err, transaction)
	}
}

type fakeDatabase struct{ transaction *fakeTransaction }

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeTransaction struct {
	row                                              fakeRow
	locked, positionsDeferred, committed, rolledBack bool
	statement                                        string
	arguments                                        []any
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
