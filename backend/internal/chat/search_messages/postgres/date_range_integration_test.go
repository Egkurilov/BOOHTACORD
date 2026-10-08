package searchmessagespostgres

import (
	"errors"
	"testing"
	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

func TestDateRangeInclusiveStartExclusiveEndAndPrivateMixedCursor(t *testing.T) {
	fixture := newSearchFixture(t)
	rows := seedSearchRows(t, fixture)
	// UUIDs may coincide across tables: kind must remain the final cursor tie breaker.
	if _, err := fixture.pool.Exec(t.Context(), "UPDATE direct_message_messages SET id=$1 WHERE id=$2", rows.channelNewest, rows.dmNewest); err != nil {
		t.Fatal(err)
	}
	rows.dmNewest = rows.channelNewest
	service := searchmessages.New(New(NewPoolDatabase(fixture.pool)))
	input := searchmessages.Input{ActorID: fixture.actorID, Query: "orbit", Limit: 1,
		CreatedFrom: "2026-09-25T03:05:00+03:00", CreatedBefore: "2026-09-25T03:06:00+03:00"}
	for _, kind := range []string{searchmessages.KindDirectMessage, searchmessages.KindChannel} {
		page, err := service.Search(t.Context(), input)
		if err != nil || len(page.Messages) != 1 || page.Messages[0].ID != rows.channelNewest || page.Messages[0].Kind != kind {
			t.Fatalf("page=%+v err=%v", page, err)
		}
		input.Before = page.NextCursor
	}
	if input.Before != "" {
		t.Fatal("last page retained cursor")
	}
	input.Limit, input.CreatedFrom, input.CreatedBefore = 20, "2026-09-25T00:01:00Z", "2026-09-25T00:05:00Z"
	page, err := service.Search(t.Context(), input)
	if err != nil || len(page.Messages) != 1 || page.Messages[0].ID != rows.channelOlder {
		t.Fatalf("exclusive end=%+v err=%v", page, err)
	}
	input.ActorID, input.CreatedFrom, input.CreatedBefore = fixture.adminID, "2026-09-25T00:05:00Z", "2026-09-25T00:06:00Z"
	page, err = service.Search(t.Context(), input)
	if err != nil || len(page.Messages) != 1 || page.Messages[0].ID != rows.channelNewest {
		t.Fatalf("admin scope=%+v err=%v", page, err)
	}
	input.DirectMessageID = fixture.dmID
	_, err = service.Search(t.Context(), input)
	if !errors.Is(err, searchmessages.ErrConversationUnavailable) {
		t.Fatalf("foreign DM err=%v", err)
	}
}

func TestDateRangeDoesNotReviveDeletedMessagesOrHiddenAttachments(t *testing.T) {
	fixture := newSearchFixture(t)
	rows := seedSearchRows(t, fixture)
	addSearchAttachment(t, fixture, rows.channelNewest, false, "ATTACHED")
	addSearchAttachment(t, fixture, rows.channelOlder, false, "HIDDEN")
	addSearchAttachment(t, fixture, rows.dmNewest, true, "ATTACHED")
	if _, err := fixture.pool.Exec(t.Context(), "UPDATE direct_message_messages SET body='', deleted_at=now() WHERE id=$1", rows.dmNewest); err != nil {
		t.Fatal(err)
	}
	service := searchmessages.New(New(NewPoolDatabase(fixture.pool)))
	attached := true
	input := searchmessages.Input{ActorID: fixture.actorID, Query: "orbit", Limit: 20, HasAttachment: &attached,
		CreatedFrom: "2026-09-25T00:00:00Z", CreatedBefore: "2026-09-26T00:00:00Z"}
	page, err := service.Search(t.Context(), input)
	if err != nil || len(page.Messages) != 1 || page.Messages[0].ID != rows.channelNewest {
		t.Fatalf("attached page=%+v err=%v", page, err)
	}
	attached = false
	page, err = service.Search(t.Context(), input)
	if err != nil || len(page.Messages) != 1 || page.Messages[0].ID != rows.channelOlder {
		t.Fatalf("hidden page=%+v err=%v", page, err)
	}
	if _, err := fixture.pool.Exec(t.Context(), "UPDATE messages SET body='', deleted_at=now() WHERE id=$1", rows.channelOlder); err != nil {
		t.Fatal(err)
	}
	page, err = service.Search(t.Context(), input)
	if err != nil || len(page.Messages) != 0 {
		t.Fatalf("deleted page=%+v err=%v", page, err)
	}
}
