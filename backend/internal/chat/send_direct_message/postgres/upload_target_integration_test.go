package senddirectmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	authorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
	authorizepostgres "voice-platform/backend/internal/storage/authorize_direct_message_attachment/postgres"
	finalize "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment"
	finalizepostgres "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment/postgres"
)

func TestDMUploadTargetIsRecheckedInPostgres(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	auth := authorize.New(authorizepostgres.New(authorizepostgres.NewPoolDatabase(f.pool)))
	store := finalizepostgres.New(finalizepostgres.NewPoolDatabase(f.pool))
	if err := auth.Authorize(ctx, authorize.Input{ActorID: f.actor, DirectMessageID: f.pair}); err != nil {
		t.Fatal(err)
	}
	if err := auth.Authorize(ctx, authorize.Input{ActorID: f.outsider, DirectMessageID: f.pair}); !errors.Is(err, authorize.ErrTargetUnavailable) {
		t.Fatalf("foreign admin auth error=%v", err)
	}
	request := finalize.Request{ID: uuid.NewString(), ActorID: f.actor, DirectMessageID: f.pair, OriginalName: "dm.txt", StorageKey: uuid.NewString(), SizeBytes: 25_000_000}
	result, err := store.Create(ctx, request)
	if err != nil || result.DirectMessageID != f.pair || result.SizeBytes != 25_000_000 {
		t.Fatalf("result=%#v error=%v", result, err)
	}
	request.ID, request.ActorID, request.StorageKey = uuid.NewString(), f.outsider, uuid.NewString()
	if _, err := store.Create(ctx, request); !errors.Is(err, finalize.ErrTargetUnavailable) {
		t.Fatalf("foreign admin finalize error=%v", err)
	}
	if _, err := f.pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, f.peer); err != nil {
		t.Fatal(err)
	}
	if err := auth.Authorize(ctx, authorize.Input{ActorID: f.actor, DirectMessageID: f.pair}); !errors.Is(err, authorize.ErrTargetUnavailable) {
		t.Fatalf("blocked auth error=%v", err)
	}
	request.ID, request.ActorID, request.StorageKey = uuid.NewString(), f.actor, uuid.NewString()
	if _, err := store.Create(ctx, request); !errors.Is(err, finalize.ErrTargetUnavailable) {
		t.Fatalf("blocked finalize error=%v", err)
	}
}
