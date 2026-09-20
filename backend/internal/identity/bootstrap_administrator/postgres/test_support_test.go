package bootstrappostgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgconn"
)

type fakeDatabase struct {
	transaction *fakeTransaction
}

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type execution struct {
	statement string
	arguments []any
}

type fakeTransaction struct {
	rows       []fakeRow
	locked     bool
	committed  bool
	rolledBack bool
	executions []execution
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.locked = true
	return nil
}

func (transaction *fakeTransaction) QueryRow(_ context.Context, _ string, _ ...any) Row {
	row := transaction.rows[0]
	transaction.rows = transaction.rows[1:]
	return row
}

func (transaction *fakeTransaction) Exec(_ context.Context, statement string, arguments ...any) (pgconn.CommandTag, error) {
	transaction.executions = append(transaction.executions, execution{statement: statement, arguments: arguments})
	return pgconn.NewCommandTag("INSERT 0 1"), nil
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
	boolValue bool
	err       error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	*destinations[0].(*bool) = row.boolValue
	return nil
}
