package archivereadonlytextpostgres

import (
	"context"
	"testing"
	archive "voice-platform/backend/internal/channel/archive_readonly_text"
	history "voice-platform/backend/internal/chat/list_text_messages"
	historypg "voice-platform/backend/internal/chat/list_text_messages/postgres"
	search "voice-platform/backend/internal/chat/search_messages"
	searchpg "voice-platform/backend/internal/chat/search_messages/postgres"
)

type revokeHistory struct {
	historypg.Database
	beforeData func()
}

func (d revokeHistory) Query(ctx context.Context, sql string, args ...any) (historypg.Rows, error) {
	d.beforeData()
	return d.Database.Query(ctx, sql, args...)
}

type revokeSearch struct {
	searchpg.Database
	beforeData func()
}

func (d revokeSearch) Query(ctx context.Context, sql string, args ...any) (searchpg.Rows, error) {
	d.beforeData()
	return d.Database.Query(ctx, sql, args...)
}

func TestArchiveReadRechecksBlockAfterAvailabilityProbe(t *testing.T) {
	f := newArchiveFixture(t)
	_, err := archive.New(New(f.pool)).Archive(t.Context(), archive.Input{ActorID: f.admin, ChannelID: f.channel, ExpectedRevision: f.revision(t), Confirm: true})
	if err != nil {
		t.Fatal(err)
	}
	block := func() {
		if _, err := f.pool.Exec(t.Context(), "UPDATE users SET blocked_at=now() WHERE id=$1", f.member); err != nil {
			t.Fatal(err)
		}
	}
	h := history.New(historypg.New(revokeHistory{historypg.NewPoolDatabase(f.pool), block}))
	page, err := h.List(t.Context(), history.Input{ActorID: f.member, ChannelID: f.channel, Limit: 20, ReadArchive: true})
	if err != nil || len(page.Messages) != 0 {
		t.Fatalf("revoked history leaked %d rows, err=%v", len(page.Messages), err)
	}
	if _, err := f.pool.Exec(t.Context(), "UPDATE users SET blocked_at=NULL WHERE id=$1", f.member); err != nil {
		t.Fatal(err)
	}
	s := search.New(searchpg.New(revokeSearch{searchpg.NewPoolDatabase(f.pool), block}))
	matches, err := s.Search(t.Context(), search.Input{ActorID: f.member, ChannelID: f.channel, Query: "orbit", Limit: 20, ReadArchive: true})
	if err != nil || len(matches.Messages) != 0 {
		t.Fatalf("revoked search leaked %d rows, err=%v", len(matches.Messages), err)
	}
}
