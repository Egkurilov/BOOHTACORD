package archivereadonlytextpostgres

import (
	"errors"
	"testing"
	archive "voice-platform/backend/internal/channel/archive_readonly_text"
	list "voice-platform/backend/internal/channel/list_archived_text"
	listpg "voice-platform/backend/internal/channel/list_archived_text/postgres"
	restore "voice-platform/backend/internal/channel/restore_readonly_text"
	restorepg "voice-platform/backend/internal/channel/restore_readonly_text/postgres"
)

func TestReadonlyArchiveLifecycleKeepsIDAndExcludesDeletedVoiceAndBlocked(t *testing.T) {
	f := newArchiveFixture(t)
	if _, err := f.pool.Exec(t.Context(), "UPDATE guild_settings SET welcome_channel_id=$1 WHERE singleton", f.channel); err != nil {
		t.Fatal(err)
	}
	service := archive.New(New(f.pool))
	revision := f.revision(t)
	for _, in := range []archive.Input{{ActorID: f.member, ChannelID: f.channel, ExpectedRevision: revision, Confirm: true}, {ActorID: f.admin, ChannelID: f.voice, ExpectedRevision: revision, Confirm: true}, {ActorID: f.admin, ChannelID: f.deleted, ExpectedRevision: revision, Confirm: true}, {ActorID: f.admin, ChannelID: f.channel, ExpectedRevision: revision + 1, Confirm: true}} {
		if _, err := service.Archive(t.Context(), in); !errors.Is(err, archive.ErrConflict) {
			t.Fatalf("rejected archive err=%v", err)
		}
	}
	result, err := service.Archive(t.Context(), archive.Input{ActorID: f.admin, ChannelID: f.channel, ExpectedRevision: revision, Confirm: true})
	if err != nil || result.ID != f.channel || result.Revision != revision+1 {
		t.Fatalf("archive=%+v err=%v", result, err)
	}
	var welcome *string
	var audited int
	if err = f.pool.QueryRow(t.Context(), "SELECT welcome_channel_id::text FROM guild_settings WHERE singleton").Scan(&welcome); err != nil || welcome != nil {
		t.Fatalf("welcome not cleared %v", err)
	}
	if err = f.pool.QueryRow(t.Context(), "SELECT count(*) FROM audit_events WHERE event_type='TEXT_CHANNEL_ARCHIVED_READONLY'").Scan(&audited); err != nil || audited != 1 {
		t.Fatalf("archive not audited %v", err)
	}
	reader := list.New(listpg.New(f.pool))
	page, err := reader.List(t.Context(), list.Input{ActorID: f.member, Limit: 20})
	if err != nil || len(page.Channels) != 1 || page.Channels[0].ID != f.channel {
		t.Fatalf("list=%+v err=%v", page, err)
	}
	page, err = reader.List(t.Context(), list.Input{ActorID: f.blocked, Limit: 20})
	if err != nil || len(page.Channels) != 0 {
		t.Fatalf("blocked=%+v err=%v", page, err)
	}
	restorer := restore.New(restorepg.New(f.pool))
	if _, err = restorer.Restore(t.Context(), restore.Input{ActorID: f.admin, ChannelID: f.deleted, ExpectedRevision: result.Revision}); !errors.Is(err, restore.ErrConflict) {
		t.Fatalf("deleted restored: %v", err)
	}
	restored, err := restorer.Restore(t.Context(), restore.Input{ActorID: f.admin, ChannelID: f.channel, ExpectedRevision: result.Revision})
	if err != nil || restored.ID != f.channel || restored.Revision != revision+2 {
		t.Fatalf("restore=%+v err=%v", restored, err)
	}
	var count int
	if err = f.pool.QueryRow(t.Context(), "SELECT count(*) FROM messages WHERE id=$1 AND channel_id=$2", f.message, f.channel).Scan(&count); err != nil || count != 1 {
		t.Fatalf("history lost count=%d err=%v", count, err)
	}
}
