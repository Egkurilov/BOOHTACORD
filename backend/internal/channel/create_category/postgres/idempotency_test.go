package categorypostgres

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/create_category"
)

func TestRepositoryCreatesReceiptInSameTransaction(t *testing.T) {
	transaction := &fakeTransaction{rows: []fakeRow{{err: pgx.ErrNoRows}, {values: []any{"category-1", "Игры", 0, int64(3)}}}}
	request := createcategory.Request{ID: "category-1", ActorID: "member-1", Name: "Игры", ClientRequestID: "request-1", IntentHash: "hash"}
	result, err := New(&fakeDatabase{transaction: transaction}).Create(context.Background(), request)
	if err != nil || result.ID != "category-1" || transaction.execCalls != 1 || !transaction.committed {
		t.Fatalf("result = %#v, error = %v, tx = %#v", result, err, transaction)
	}
}

func TestRepositoryReturnsExistingReceiptWithoutMutation(t *testing.T) {
	transaction := &fakeTransaction{rows: []fakeRow{{values: []any{"request-1", "CATEGORY_CREATE", "hash", "category-1", "CATEGORY", "ACTIVE", int64(3), 201}}}}
	request := createcategory.Request{ID: "new-id", ActorID: "member-1", Name: "Игры", ClientRequestID: "request-1", IntentHash: "hash"}
	result, err := New(&fakeDatabase{transaction: transaction}).Create(context.Background(), request)
	if err != nil || result.ID != "category-1" || transaction.queryIndex != 1 || transaction.execCalls != 0 {
		t.Fatalf("result = %#v, error = %v, tx = %#v", result, err, transaction)
	}
}
