package createtextmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
)

func TestRepositoryRejectsCrossChannelReplyWithoutClaimingAttachment(t *testing.T) {
	fixture := newTextMessageFixture(t)
	ctx := context.Background()
	otherChannelID := uuid.NewString()
	_, err := fixture.pool.Exec(ctx, `
		INSERT INTO channels (id, category_id, name, kind, position)
		SELECT $1, category_id, 'Other text', 'TEXT', 1 FROM channels WHERE id = $2`,
		otherChannelID, fixture.channelID)
	if err != nil {
		t.Fatal("seed other text channel:", err)
	}
	repository := New(NewPoolDatabase(fixture.pool))
	otherMessage, err := repository.Create(ctx, createtextmessage.Request{
		ID: uuid.NewString(), Input: createtextmessage.Input{
			ActorID: fixture.authorID, ChannelID: otherChannelID,
			ClientMessageID: uuid.NewString(), Body: "source message",
		},
	})
	if err != nil {
		t.Fatal("send source message:", err)
	}
	clientID := uuid.NewString()
	_, err = repository.Create(ctx, createtextmessage.Request{
		ID: uuid.NewString(), Input: createtextmessage.Input{
			ActorID: fixture.authorID, ChannelID: fixture.channelID,
			ClientMessageID: clientID, Body: "invalid reply",
			ReplyToID: otherMessage.ID, AttachmentIDs: []string{fixture.attachmentID},
		},
	})
	if !errors.Is(err, createtextmessage.ErrChannelUnavailable) {
		t.Fatalf("cross-channel reply error = %v, want ErrChannelUnavailable", err)
	}
	assertMessageCount(t, fixture, clientID, 0)
	var links int
	if err := fixture.pool.QueryRow(ctx,
		"SELECT count(*) FROM message_attachments WHERE attachment_id = $1", fixture.attachmentID,
	).Scan(&links); err != nil {
		t.Fatal("count attachment links:", err)
	}
	if links != 0 {
		t.Fatalf("attachment links = %d, want 0", links)
	}
	var state string
	if err := fixture.pool.QueryRow(ctx,
		"SELECT state FROM attachments WHERE id = $1", fixture.attachmentID,
	).Scan(&state); err != nil {
		t.Fatal("read attachment state:", err)
	}
	if state != "UNATTACHED" {
		t.Fatalf("attachment state = %q, want UNATTACHED", state)
	}
}
