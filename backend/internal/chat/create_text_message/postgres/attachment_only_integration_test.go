package createtextmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	create "voice-platform/backend/internal/chat/create_text_message"
)

func TestAttachmentOnlyTextMessageClaimsOneFileAtomically(t *testing.T) {
	fixture := newTextMessageFixture(t)
	ctx := context.Background()
	clientID := uuid.NewString()
	result, err := New(NewPoolDatabase(fixture.pool)).Create(ctx, create.Request{ID: uuid.NewString(), Input: create.Input{
		ActorID: fixture.authorID, ChannelID: fixture.channelID, ClientMessageID: clientID,
		Body: "", AttachmentIDs: []string{fixture.attachmentID},
	}})
	if err != nil || result.ID == "" || result.Body != "" {
		t.Fatalf("message = %#v, error = %v", result, err)
	}
	assertMessageCount(t, fixture, clientID, 1)
	var linkedID, state string
	err = fixture.pool.QueryRow(ctx, `SELECT ma.attachment_id::text, a.state FROM message_attachments ma JOIN attachments a ON a.id = ma.attachment_id WHERE ma.message_id = $1`, result.ID).Scan(&linkedID, &state)
	if err != nil || linkedID != fixture.attachmentID || state != "ATTACHED" {
		t.Fatalf("linked = %q, state = %q, error = %v", linkedID, state, err)
	}
}

func TestAttachmentOnlyTextMessageRejectsForeignOrClaimedFile(t *testing.T) {
	fixture := newTextMessageFixture(t)
	ctx := context.Background()
	foreignID := uuid.NewString()
	foreignOwner := uuid.NewString()
	if _, err := fixture.pool.Exec(ctx, `INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'otherattachmentowner', 'Other', 'test-only', 'MEMBER')`, foreignOwner); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.pool.Exec(ctx, `INSERT INTO attachments (id, owner_id, channel_id, original_name, storage_key, byte_size, state) VALUES ($1, $2, $3, 'foreign.txt', $4, 1, 'UNATTACHED')`, foreignID, foreignOwner, fixture.channelID, uuid.NewString()); err != nil {
		t.Fatal(err)
	}
	repository := New(NewPoolDatabase(fixture.pool))
	for _, attachmentID := range []string{foreignID, fixture.attachmentID} {
		if attachmentID == fixture.attachmentID {
			if _, err := fixture.pool.Exec(ctx, `UPDATE attachments SET state = 'ATTACHED', attached_at = now() WHERE id = $1`, attachmentID); err != nil {
				t.Fatal(err)
			}
		}
		clientID := uuid.NewString()
		_, err := repository.Create(ctx, create.Request{ID: uuid.NewString(), Input: create.Input{
			ActorID: fixture.authorID, ChannelID: fixture.channelID, ClientMessageID: clientID,
			Body: "", AttachmentIDs: []string{attachmentID},
		}})
		if !errors.Is(err, create.ErrChannelUnavailable) {
			t.Fatalf("attachment %q: error = %v", attachmentID, err)
		}
		assertMessageCount(t, fixture, clientID, 0)
	}
}

func TestRepositoryRejectsEmptyTextMessageWithoutFile(t *testing.T) {
	fixture := newTextMessageFixture(t)
	clientID := uuid.NewString()
	_, err := New(NewPoolDatabase(fixture.pool)).Create(context.Background(), create.Request{ID: uuid.NewString(), Input: create.Input{
		ActorID: fixture.authorID, ChannelID: fixture.channelID, ClientMessageID: clientID,
	}})
	if !errors.Is(err, create.ErrChannelUnavailable) {
		t.Fatalf("error = %v", err)
	}
	assertMessageCount(t, fixture, clientID, 0)
}
