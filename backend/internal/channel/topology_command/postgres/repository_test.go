package topologycommandpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	topologycommand "voice-platform/backend/internal/channel/topology_command"
)

func TestReadOwnReturnsReceiptAndScopesByActor(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"request-1", "CATEGORY_CREATE", "hash", "category-1", "CATEGORY", "ACTIVE", int64(7), 201}}}
	receipt, err := New(database).ReadOwn(context.Background(), "actor-1", "request-1")
	if err != nil || receipt.ResourceID != "category-1" || receipt.TopologyRevision != 7 {
		t.Fatalf("ReadOwn() = %#v, %v", receipt, err)
	}
	if !strings.Contains(database.statement, "actor_id = $1") || database.arguments[0] != "actor-1" {
		t.Fatalf("query = %q %#v", database.statement, database.arguments)
	}
}

func TestCheckExistingDetectsMismatch(t *testing.T) {
	recorder := Recorder{}
	receipt := topologycommand.Receipt{IntentHash: "old"}
	if _, err := recorder.CheckExisting(receipt, "new"); !errors.Is(err, topologycommand.ErrKeyReused) {
		t.Fatalf("error = %v", err)
	}
	if got, err := recorder.CheckExisting(receipt, "old"); err != nil || got != receipt {
		t.Fatalf("result = %#v, %v", got, err)
	}
}

func TestRecorderPersistsMetadataWithoutRequestBody(t *testing.T) {
	transaction := &fakeCommandTransaction{}
	receipt := topologycommand.Receipt{ClientRequestID: "request-1", Operation: topologycommand.OperationCategoryCreate, IntentHash: "hash", ResourceID: "category-1", ResourceType: "CATEGORY", ResultState: "ACTIVE", TopologyRevision: 7, ResponseStatus: 201}
	if err := (Recorder{}).Record(context.Background(), transaction, "actor-1", receipt); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(transaction.statement, "INSERT INTO topology_command_receipts") || transaction.arguments[0] != "actor-1" || len(transaction.arguments) != 9 {
		t.Fatalf("record = %q %#v", transaction.statement, transaction.arguments)
	}
}

type fakeDatabase struct {
	row       Row
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement, database.arguments = statement, arguments
	return database.row
}

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	for i, value := range row.values {
		switch destination := destinations[i].(type) {
		case *string:
			*destination = value.(string)
		case *int64:
			*destination = value.(int64)
		case *int:
			*destination = value.(int)
		}
	}
	return nil
}

type fakeCommandTransaction struct {
	statement string
	arguments []any
}

func (transaction *fakeCommandTransaction) QueryRow(context.Context, string, ...any) Row {
	return fakeRow{err: errors.New("missing")}
}

func (transaction *fakeCommandTransaction) Exec(_ context.Context, statement string, arguments ...any) error {
	transaction.statement, transaction.arguments = statement, arguments
	return nil
}
