package finalizeclosedvoicechannelpostgres

import "context"

type fakeDatabase struct {
	rows        *fakeRows
	transaction *fakeTransaction
	query       string
	queryArgs   []any
}

func (database *fakeDatabase) Query(_ context.Context, query string, args ...any) (Rows, error) {
	database.query, database.queryArgs = query, args
	return database.rows, nil
}
func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type fakeRows struct {
	values []string
	index  int
}

func (rows *fakeRows) Next() bool { return rows.index < len(rows.values) }
func (rows *fakeRows) Scan(destinations ...any) error {
	*destinations[0].(*string) = rows.values[rows.index]
	rows.index++
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return nil }

type fakeTransaction struct {
	row                           fakeRow
	statement                     string
	args                          []any
	locked, committed, rolledBack bool
	commitErr                     error
}

func (transaction *fakeTransaction) Lock(context.Context, int64) error {
	transaction.locked = true
	return nil
}
func (transaction *fakeTransaction) QueryRow(_ context.Context, statement string, args ...any) Row {
	transaction.statement, transaction.args = statement, args
	return transaction.row
}
func (transaction *fakeTransaction) Commit(context.Context) error {
	transaction.committed = true
	return transaction.commitErr
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
