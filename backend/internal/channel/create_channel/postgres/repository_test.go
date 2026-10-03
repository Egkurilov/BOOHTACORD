package channelpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/create_channel"
)

func TestRepositoryCreatesOrderedChannelAndAuditsTopologyChange(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{values: []any{"channel-1", "category-1", "Голос", "VOICE", 0, int64(2)}}}
	repository := New(&fakeDatabase{transaction: transaction})
	result, err := repository.Create(context.Background(), createchannel.Request{ID: "channel-1", Input: createchannel.Input{ActorID: "admin-1", CategoryID: "category-1", Name: "Голос", Kind: createchannel.KindVoice}})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	want := createchannel.Result{ID: "channel-1", CategoryID: "category-1", Name: "Голос", Kind: createchannel.KindVoice, Position: 0, Revision: 2}
	if !transaction.locked || !transaction.committed || transaction.rolledBack || result != want {
		t.Fatalf("transaction = %#v, result = %#v", transaction, result)
	}
	if transaction.arguments[0] != "channel-1" || transaction.arguments[1] != "category-1" || transaction.arguments[2] != "Голос" || transaction.arguments[3] != "VOICE" || transaction.arguments[4] != "admin-1" {
		t.Fatalf("arguments = %#v", transaction.arguments)
	}
	for _, fragment := range []string{"FROM categories", "INSERT INTO channels", "SELECT TRUE, 1 FROM created", "revision = channel_topology_state.revision + 1", "INSERT INTO audit_events"} {
		if !strings.Contains(transaction.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, transaction.statement)
		}
	}
}

func TestRepositoryMapsUnknownCategory(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Create(context.Background(), createchannel.Request{})
	if !errors.Is(err, createchannel.ErrCategoryNotFound) || !transaction.rolledBack {
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
