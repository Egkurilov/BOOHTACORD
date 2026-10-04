package descriptionpostgres

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/channel/update_description"
	"voice-platform/backend/internal/database/migrate"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestUpdateDescriptionPersistsUnderRevisionAndAuditsMetadata(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	actorID, categoryID, channelID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	for _, seed := range []struct {
		statement string
		args      []any
	}{
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'descriptionadmin','Admin','test','ADMINISTRATOR')`, []any{actorID}},
		{`INSERT INTO channel_topology_state (singleton,revision) VALUES (TRUE,1)`, nil},
		{`INSERT INTO categories (id,name,position) VALUES ($1,'General',0)`, []any{categoryID}},
		{`INSERT INTO channels (id,category_id,name,kind,position) VALUES ($1,$2,'General','TEXT',0)`, []any{channelID, categoryID}},
	} {
		if _, err := pool.Exec(ctx, seed.statement, seed.args...); err != nil {
			t.Fatal(err)
		}
	}
	repository := New(NewPoolDatabase(pool))
	result, err := repository.Update(ctx, updatedescription.Input{
		ActorID: actorID, ChannelID: channelID, Description: "Общение на любые темы", ExpectedRevision: 1,
	})
	if err != nil || result.ID != channelID || result.Description != "Общение на любые темы" || result.Revision != 2 {
		t.Fatalf("result=%#v err=%v", result, err)
	}
	var description, kind, eventType, metadata string
	var revision int64
	if err := pool.QueryRow(ctx, `SELECT description, kind FROM channels WHERE id=$1`, channelID).Scan(&description, &kind); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT revision FROM channel_topology_state WHERE singleton=TRUE`).Scan(&revision); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT event_type, metadata::text FROM audit_events ORDER BY id DESC LIMIT 1`).Scan(&eventType, &metadata); err != nil {
		t.Fatal(err)
	}
	if description != result.Description || kind != "TEXT" || revision != 2 || eventType != "CHANNEL_DESCRIPTION_UPDATED" || !strings.Contains(metadata, channelID) || strings.Contains(metadata, description) {
		t.Fatalf("description=%q kind=%q revision=%d event=%q metadata=%q", description, kind, revision, eventType, metadata)
	}
	if _, err := repository.Update(ctx, updatedescription.Input{ActorID: actorID, ChannelID: channelID, Description: "stale", ExpectedRevision: 1}); err != updatedescription.ErrRevisionConflict {
		t.Fatalf("stale update error=%v", err)
	}
}
