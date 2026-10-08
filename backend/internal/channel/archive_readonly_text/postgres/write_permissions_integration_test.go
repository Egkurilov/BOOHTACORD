package archivereadonlytextpostgres

import (
	"errors"
	"github.com/google/uuid"
	"testing"
	archive "voice-platform/backend/internal/channel/archive_readonly_text"
	create "voice-platform/backend/internal/chat/create_text_message"
	createpg "voice-platform/backend/internal/chat/create_text_message/postgres"
	deletion "voice-platform/backend/internal/chat/delete_text_message"
	deletepg "voice-platform/backend/internal/chat/delete_text_message/postgres"
	edit "voice-platform/backend/internal/chat/edit_text_message"
	editpg "voice-platform/backend/internal/chat/edit_text_message/postgres"
	authorize "voice-platform/backend/internal/storage/authorize_text_attachment"
	authorizepg "voice-platform/backend/internal/storage/authorize_text_attachment/postgres"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
	finalizepg "voice-platform/backend/internal/storage/finalize_staged_text_attachment/postgres"
)

func TestArchiveRejectsFreshSendIdempotentReplayAndEdit(t *testing.T) {
	f := newArchiveFixture(t)
	if _, err := archive.New(New(f.pool)).Archive(t.Context(), archive.Input{ActorID: f.admin, ChannelID: f.channel, ExpectedRevision: f.revision(t), Confirm: true}); err != nil {
		t.Fatal(err)
	}
	sender := create.New(createpg.New(createpg.NewPoolDatabase(f.pool)))
	for _, client := range []string{uuid.NewString(), f.client} {
		if _, err := sender.Create(t.Context(), create.Input{ActorID: f.member, ChannelID: f.channel, ClientMessageID: client, Body: "attempt"}); !errors.Is(err, create.ErrChannelUnavailable) {
			t.Fatalf("archived send/replay err=%v", err)
		}
	}
	editor := editpg.New(editpg.NewPoolDatabase(f.pool))
	if _, err := editor.Edit(t.Context(), edit.Request{Input: edit.Input{ActorID: f.member, ChannelID: f.channel, MessageID: f.message, Body: "changed", ExpectedRevision: 1}}); !errors.Is(err, edit.ErrConflict) {
		t.Fatalf("archived edit err=%v", err)
	}
	deleter := deletepg.New(deletepg.NewPoolDatabase(f.pool))
	if _, err := deleter.Delete(t.Context(), deletion.Request{Input: deletion.Input{ActorID: f.admin, ActorRole: "ADMINISTRATOR", ChannelID: f.channel, MessageID: f.message}}); !errors.Is(err, deletion.ErrDeleteDenied) {
		t.Fatalf("archived admin delete %v", err)
	}
	uploadACL := authorizepg.New(authorizepg.NewPoolDatabase(f.pool))
	if err := uploadACL.Authorize(t.Context(), authorize.Input{ActorID: f.member, ChannelID: f.channel}); !errors.Is(err, authorize.ErrTargetUnavailable) {
		t.Fatalf("archived upload %v", err)
	}
	storage := finalizepg.New(finalizepg.NewPoolDatabase(f.pool))
	if _, err := storage.Create(t.Context(), finalize.Request{ID: uuid.NewString(), ActorID: f.member, ChannelID: f.channel, OriginalName: "new.txt", StorageKey: uuid.NewString(), SizeBytes: 1}); !errors.Is(err, finalize.ErrTargetUnavailable) {
		t.Fatalf("archived upload finalization %v", err)
	}
	var body string
	if err := f.pool.QueryRow(t.Context(), "SELECT body FROM messages WHERE id=$1", f.message).Scan(&body); err != nil || body != "orbit history" {
		t.Fatalf("body mutated err=%v", err)
	}
}
