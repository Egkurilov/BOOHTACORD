package categorypostgres

import (
	"context"
	"strings"
	"testing"

	"voice-platform/backend/internal/channel/create_category"
)

func TestRepositoryLocksTopologyAndAuditsCategoryCreation(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"category-1", "Общее", 0, int64(1)}}}
	repository := New(&fakeDatabase{transaction: transaction})
	result, err := repository.Create(context.Background(), createcategory.Request{ID: "category-1", ActorID: "admin-1", Name: "Общее"})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if !transaction.locked || !transaction.committed || transaction.rolledBack || result != (createcategory.Result{ID: "category-1", Name: "Общее", Position: 0, Revision: 1}) {
		t.Fatalf("transaction = %#v, result = %#v", transaction, result)
	}
	if transaction.arguments[0] != "category-1" || transaction.arguments[1] != "Общее" || transaction.arguments[2] != "admin-1" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"INSERT INTO categories", "SELECT TRUE, 1 FROM created", "revision = channel_topology_state.revision + 1", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
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
	rows       []fakeRow
	queryIndex int
	execCalls  int
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
	transaction.statement = statement
	transaction.arguments = arguments
	if transaction.queryIndex < len(transaction.rows) {
		row := transaction.rows[transaction.queryIndex]
		transaction.queryIndex++
		return row
	}
	return transaction.row
}

func (transaction *fakeTransaction) Exec(context.Context, string, ...any) error {
	transaction.execCalls++
	return nil
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
		case *int:
			*destination = value.(int)
		case *int64:
			*destination = value.(int64)
		}
	}
	return nil
}
