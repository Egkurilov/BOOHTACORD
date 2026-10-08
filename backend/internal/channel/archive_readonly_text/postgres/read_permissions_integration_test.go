package archivereadonlytextpostgres

import (
	"errors"
	"testing"
	archive "voice-platform/backend/internal/channel/archive_readonly_text"
	history "voice-platform/backend/internal/chat/list_text_messages"
	historypg "voice-platform/backend/internal/chat/list_text_messages/postgres"
	search "voice-platform/backend/internal/chat/search_messages"
	searchpg "voice-platform/backend/internal/chat/search_messages/postgres"
	download "voice-platform/backend/internal/storage/download_text_attachment"
	downloadpg "voice-platform/backend/internal/storage/download_text_attachment/postgres"
)

func TestArchiveHistorySearchAndFilesRequireExplicitModeAndActiveReader(t *testing.T) {
	f := newArchiveFixture(t)
	if _, err := archive.New(New(f.pool)).Archive(t.Context(), archive.Input{ActorID: f.admin, ChannelID: f.channel, ExpectedRevision: f.revision(t), Confirm: true}); err != nil {
		t.Fatal(err)
	}
	h := history.New(historypg.New(historypg.NewPoolDatabase(f.pool)))
	s := search.New(searchpg.New(searchpg.NewPoolDatabase(f.pool)))
	d := downloadpg.New(downloadpg.NewPoolDatabase(f.pool))
	for _, actor := range []string{f.member, f.admin, f.blocked} {
		allowed := actor != f.blocked
		page, err := h.List(t.Context(), history.Input{ActorID: actor, ChannelID: f.channel, Limit: 20, ReadArchive: true})
		if allowed && (err != nil || len(page.Messages) != 1) || !allowed && !errors.Is(err, history.ErrChannelUnavailable) {
			t.Fatalf("history allowed=%v page=%+v err=%v", allowed, page, err)
		}
		matches, err := s.Search(t.Context(), search.Input{ActorID: actor, ChannelID: f.channel, Query: "orbit", Limit: 20, ReadArchive: true})
		if allowed && (err != nil || len(matches.Messages) != 1) || !allowed && !errors.Is(err, search.ErrConversationUnavailable) {
			t.Fatalf("search allowed=%v page=%+v err=%v", allowed, matches, err)
		}
		_, err = d.Find(t.Context(), download.Input{ActorID: actor, ChannelID: f.channel, AttachmentID: f.file, ReadArchive: true})
		if allowed && err != nil || !allowed && !errors.Is(err, download.ErrAttachmentUnavailable) {
			t.Fatalf("file allowed=%v err=%v", allowed, err)
		}
	}
	if _, err := h.List(t.Context(), history.Input{ChannelID: f.channel, Limit: 20}); !errors.Is(err, history.ErrChannelUnavailable) {
		t.Fatalf("old history %v", err)
	}
	if _, err := s.Search(t.Context(), search.Input{ActorID: f.member, ChannelID: f.channel, Query: "orbit", Limit: 20}); !errors.Is(err, search.ErrConversationUnavailable) {
		t.Fatalf("old search %v", err)
	}
	if _, err := d.Find(t.Context(), download.Input{ActorID: f.member, ChannelID: f.channel, AttachmentID: f.file}); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("old file %v", err)
	}
	for _, id := range []string{f.deleted, f.voice} {
		if _, err := h.List(t.Context(), history.Input{ActorID: f.member, ChannelID: id, Limit: 20, ReadArchive: true}); !errors.Is(err, history.ErrChannelUnavailable) {
			t.Fatalf("inaccessible/voice history %v", err)
		}
		if _, err := s.Search(t.Context(), search.Input{ActorID: f.member, ChannelID: id, Query: "orbit", Limit: 20, ReadArchive: true}); !errors.Is(err, search.ErrConversationUnavailable) {
			t.Fatalf("inaccessible/voice search %v", err)
		}
		if _, err := d.Find(t.Context(), download.Input{ActorID: f.member, ChannelID: id, AttachmentID: f.file, ReadArchive: true}); !errors.Is(err, download.ErrAttachmentUnavailable) {
			t.Fatalf("foreign file %v", err)
		}
	}
	if _, err := f.pool.Exec(t.Context(), "UPDATE attachments SET state='HIDDEN',hidden_at=now() WHERE id=$1", f.file); err != nil {
		t.Fatal(err)
	}
	if _, err := d.Find(t.Context(), download.Input{ActorID: f.member, ChannelID: f.channel, AttachmentID: f.file, ReadArchive: true}); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("hidden file %v", err)
	}
}
