package channelpostgres

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/create_channel"
)

func TestRepositoryCreatesChannelReceiptInSameTransaction(t *testing.T) {
	transaction := &fakeTransaction{rows: []fakeRow{{err: pgx.ErrNoRows}, {values: []any{"channel-1", "category-1", "Голос", "VOICE", 0, int64(4)}}}}
	request := createchannel.Request{ID: "channel-1", Input: createchannel.Input{ActorID: "member-1", CategoryID: "category-1", Name: "Голос", Kind: createchannel.KindVoice, ClientRequestID: "request-1"}, IntentHash: "hash"}
	result, err := New(&fakeDatabase{transaction: transaction}).Create(context.Background(), request)
	if err != nil || result.ID != "channel-1" || transaction.execCalls != 1 || !transaction.committed {
		t.Fatalf("result = %#v, error = %v, tx = %#v", result, err, transaction)
	}
}
