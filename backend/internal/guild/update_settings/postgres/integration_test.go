package guildsettingspostgres

import (
	"errors"
	"strings"
	"testing"
	archivetextchannel "voice-platform/backend/internal/channel/archive_text_channel"
	archivepostgres "voice-platform/backend/internal/channel/archive_text_channel/postgres"
	"voice-platform/backend/internal/database/migrate"
	guildsettings "voice-platform/backend/internal/guild/update_settings"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestSettingsRevisionChannelValidationAndArchiveCleanup(t *testing.T) {
	f := guildfixture.New(t)
	if err := migrate.Run(f.Context, f.Pool); err != nil {
		t.Fatal("repeat migrations", err)
	}
	repo := New(f.Pool)
	initial, err := repo.Read(f.Context)
	if err != nil || initial.Name != "Моя гильдия" || initial.Revision != 1 || initial.WelcomeChannelID != nil {
		t.Fatal("singleton seed mismatch")
	}
	result, err := repo.Update(f.Context, guildsettings.Input{ActorID: f.Admin, ExpectedRevision: 1, SetName: true, Name: "New private guild", SetWelcome: true, WelcomeChannelID: f.Channel})
	if err != nil || result.Revision != 2 || result.WelcomeChannelID == nil {
		t.Fatal("update failed")
	}
	_, err = repo.Update(f.Context, guildsettings.Input{ActorID: f.Admin, ExpectedRevision: 1, SetName: true, Name: "stale"})
	if !errors.Is(err, guildsettings.ErrConflict) {
		t.Fatal("stale write accepted")
	}
	_, err = repo.Update(f.Context, guildsettings.Input{ActorID: f.Admin, ExpectedRevision: 2, SetWelcome: true, WelcomeChannelID: f.Voice})
	if !errors.Is(err, guildsettings.ErrChannel) {
		t.Fatal("VOICE accepted")
	}
	var revision int64
	if err = f.Pool.QueryRow(f.Context, `SELECT revision FROM channel_topology_state WHERE singleton=TRUE`).Scan(&revision); err != nil {
		t.Fatal(err)
	}
	_, err = archivepostgres.New(archivepostgres.NewPoolDatabase(f.Pool)).Archive(f.Context, archivetextchannel.Input{ActorID: f.Admin, ChannelID: f.Channel, ExpectedRevision: revision, ConfirmArchive: true})
	if err != nil {
		t.Fatal(err)
	}
	final, err := repo.Read(f.Context)
	if err != nil || final.WelcomeChannelID != nil || final.Revision != 3 {
		t.Fatal("archive did not atomically disable welcome")
	}
	var metadata string
	if err = f.Pool.QueryRow(f.Context, `SELECT jsonb_agg(metadata)::text FROM audit_events WHERE event_type LIKE 'GUILD_%'`).Scan(&metadata); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(metadata, "New private guild") || strings.Contains(metadata, "stale") {
		t.Fatal("guild names leaked in audit")
	}
}
