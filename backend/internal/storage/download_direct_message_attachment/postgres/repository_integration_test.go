package downloaddirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"testing"

	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
)

func TestMigrationBackedDMDownloadAuthorization(t *testing.T) {
	fixture := newAttachmentFixture(t)
	ctx := context.Background()
	repository := New(NewPoolDatabase(fixture.pool))
	input := download.Input{ActorID: fixture.actor, DirectMessageID: fixture.pair, AttachmentID: fixture.attached}
	for _, actor := range []string{fixture.actor, fixture.peer} {
		input.ActorID = actor
		metadata, err := repository.Find(ctx, input)
		if err != nil || metadata.StorageKey != fixture.storageKey || metadata.OriginalName != "private.svg" {
			t.Fatalf("participant actor=%q metadata=%#v err=%v", actor, metadata, err)
		}
	}
	for _, denied := range []download.Input{
		{ActorID: fixture.outsider, DirectMessageID: fixture.pair, AttachmentID: fixture.attached},
		{ActorID: fixture.actor, DirectMessageID: fixture.otherPair, AttachmentID: fixture.attached},
		{ActorID: fixture.actor, DirectMessageID: fixture.pair, AttachmentID: fixture.unattached},
	} {
		if _, err := repository.Find(ctx, denied); !errors.Is(err, download.ErrAttachmentUnavailable) {
			t.Fatalf("denied input=%#v err=%v", denied, err)
		}
	}
	input.ActorID = fixture.actor
	if _, err := fixture.pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, fixture.peer); err != nil {
		t.Fatal(err)
	}
	if _, err := repository.Find(ctx, input); err != nil {
		t.Fatalf("active participant lost old history when peer blocked: %v", err)
	}
	if _, err := fixture.pool.Exec(ctx, `UPDATE attachments SET state='HIDDEN',hidden_at=now() WHERE id=$1`, fixture.attached); err != nil {
		t.Fatal(err)
	}
	if _, err := repository.Find(ctx, input); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("hidden attachment err=%v", err)
	}
	if _, err := fixture.pool.Exec(ctx, `UPDATE attachments SET state='ATTACHED',hidden_at=NULL WHERE id=$1`, fixture.attached); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.pool.Exec(ctx, `UPDATE direct_message_messages SET body='',deleted_at=now() WHERE id=$1`, fixture.message); err != nil {
		t.Fatal(err)
	}
	if _, err := repository.Find(ctx, input); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("deleted message err=%v", err)
	}
}
