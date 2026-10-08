package searchmessagespostgres

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

func TestSearchFiltersAttachmentsAndAuthorsWithinReadableScope(t *testing.T) {
	fixture := newSearchFixture(t)
	rows := seedSearchRows(t, fixture)
	addSearchAttachment(t, fixture, rows.channelNewest, false, "ATTACHED")
	addSearchAttachment(t, fixture, rows.dmNewest, true, "ATTACHED")
	addSearchAttachment(t, fixture, rows.channelOlder, false, "HIDDEN")
	service := searchmessages.New(New(NewPoolDatabase(fixture.pool)))
	search := func(author string, hasAttachment bool) []searchmessages.Message {
		t.Helper()
		result, err := service.Search(context.Background(), searchmessages.Input{
			ActorID: fixture.actorID, Query: "orbit", AuthorID: author,
			HasAttachment: &hasAttachment, Limit: 20,
		})
		if err != nil {
			t.Fatal("search with filters:", err)
		}
		return result.Messages
	}
	if got := search(fixture.actorID, true); len(got) != 1 || got[0].ID != rows.channelNewest {
		t.Fatalf("author's attached channel results = %#v", got)
	}
	if got := search(fixture.actorID, false); len(got) != 1 || got[0].ID != rows.channelOlder {
		t.Fatalf("author's no-visible-attachment results = %#v", got)
	}
	if got := search(fixture.peerID, true); len(got) != 1 || got[0].ID != rows.dmNewest || got[0].Kind != searchmessages.KindDirectMessage {
		t.Fatalf("peer's attached own-DM results = %#v", got)
	}
}

func addSearchAttachment(t *testing.T, fixture searchFixture, messageID string, isDM bool, state string) {
	t.Helper()
	attachmentID, storageKey := uuid.NewString(), uuid.NewString()
	attachedAt := time.Now().UTC()
	var hiddenAt any
	if state == "HIDDEN" {
		hiddenAt = attachedAt
	}
	var channelID, directMessageID any
	ownerID := fixture.actorID
	if isDM {
		directMessageID = fixture.dmID
		ownerID = fixture.peerID
	} else {
		channelID = fixture.channelID
	}
	_, err := fixture.pool.Exec(context.Background(), `INSERT INTO attachments
		(id, owner_id, channel_id, direct_message_id, original_name, storage_key, byte_size, state, attached_at, hidden_at)
		VALUES ($1,$2,$3,$4,'fixture.txt',$5,4,$6,$7,$8)`,
		attachmentID, ownerID, channelID, directMessageID, storageKey, state, attachedAt, hiddenAt)
	if err != nil {
		t.Fatal("seed searchable attachment:", err)
	}
	link := `INSERT INTO message_attachments (message_id, attachment_id, position) VALUES ($1,$2,0)`
	if isDM {
		link = `INSERT INTO direct_message_attachments (message_id, attachment_id, position) VALUES ($1,$2,0)`
	}
	if _, err = fixture.pool.Exec(context.Background(), link, messageID, attachmentID); err != nil {
		t.Fatal("link searchable attachment:", err)
	}
}
