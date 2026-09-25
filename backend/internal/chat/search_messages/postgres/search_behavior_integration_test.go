package searchmessagespostgres

import (
	"context"
	"errors"
	"testing"

	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

func TestSearchWithPostgresRussianPhraseAndPrivateDM(t *testing.T) {
	fixture := newSearchFixture(t)
	rows := seedSearchRows(t, fixture)
	service := searchmessages.New(New(NewPoolDatabase(fixture.pool)))
	search := func(actor, query string) searchmessages.Result {
		t.Helper()
		result, err := service.Search(context.Background(), searchmessages.Input{
			ActorID: actor, Query: query, Limit: 20,
		})
		if err != nil {
			t.Fatal("search:", err)
		}
		return result
	}
	russian := search(fixture.actorID, "Ирина")
	if len(russian.Messages) != 1 || russian.Messages[0].ID != rows.russian {
		t.Fatalf("Russian body search returned %#v", russian.Messages)
	}
	phrase := search(fixture.actorID, `"точная фраза"`)
	if len(phrase.Messages) != 1 || phrase.Messages[0].ID != rows.phrase {
		t.Fatalf("phrase search returned %#v", phrase.Messages)
	}
	english := search(fixture.actorID, "orbit")
	if len(english.Messages) != 3 || english.Messages[0].ID != rows.dmNewest {
		t.Fatalf("English mixed search returned %#v", english.Messages)
	}
	admin := search(fixture.adminID, "orbit")
	if len(admin.Messages) != 2 || admin.Messages[0].ID != rows.channelNewest {
		t.Fatalf("third-party admin search returned %#v", admin.Messages)
	}
	_, err := service.Search(context.Background(), searchmessages.Input{
		ActorID: fixture.adminID, DirectMessageID: fixture.dmID, Query: "orbit", Limit: 20,
	})
	if !errors.Is(err, searchmessages.ErrConversationUnavailable) {
		t.Fatalf("admin DM filter error = %v", err)
	}
}

func TestSearchWithPostgresCursorBoundaries(t *testing.T) {
	fixture := newSearchFixture(t)
	rows := seedSearchRows(t, fixture)
	service := searchmessages.New(New(NewPoolDatabase(fixture.pool)))
	want := []string{rows.dmNewest, rows.channelNewest, rows.channelOlder}
	cursor := ""
	for index, expectedID := range want {
		result, err := service.Search(context.Background(), searchmessages.Input{
			ActorID: fixture.actorID, Query: "orbit", Limit: 1, Before: cursor,
		})
		if err != nil {
			t.Fatalf("search page %d: %v", index, err)
		}
		if len(result.Messages) != 1 || result.Messages[0].ID != expectedID {
			t.Fatalf("search page %d = %#v, want %s", index, result.Messages, expectedID)
		}
		cursor = result.NextCursor
		if index < len(want)-1 && cursor == "" {
			t.Fatalf("search page %d omitted next cursor", index)
		}
	}
	if cursor != "" {
		t.Fatal("last page retained a next cursor")
	}
}
