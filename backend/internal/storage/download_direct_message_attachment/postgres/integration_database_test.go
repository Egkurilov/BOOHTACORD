package downloaddirectmessageattachmentpostgres

import (
	"context"
	"fmt"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

type attachmentFixture struct {
	pool                                            *pgxpool.Pool
	actor, peer, outsider, pair, otherPair, message string
	attached, unattached, storageKey                string
}

func newAttachmentFixture(t *testing.T) attachmentFixture {
	t.Helper()
	url := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("VOICE_PLATFORM_TEST_DATABASE_URL is not configured")
	}
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatal(err)
	}
	address := net.ParseIP(config.ConnConfig.Host)
	if config.ConnConfig.Host != "localhost" && (address == nil || !address.IsLoopback()) {
		t.Fatal("test database must use a loopback address")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	admin, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	if err := admin.Ping(ctx); err != nil {
		admin.Close()
		t.Fatal(err)
	}
	schema := "be10_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		admin.Close()
		t.Fatal(err)
	}
	isolated := config.Copy()
	if isolated.ConnConfig.RuntimeParams == nil {
		isolated.ConnConfig.RuntimeParams = map[string]string{}
	}
	isolated.ConnConfig.RuntimeParams["search_path"] = schema
	pool, err := pgxpool.NewWithConfig(ctx, isolated)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		pool.Close()
		cleanup, done := context.WithTimeout(context.Background(), 10*time.Second)
		defer done()
		_, _ = admin.Exec(cleanup, "DROP SCHEMA "+schema+" CASCADE")
		admin.Close()
	})
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	fixture := attachmentFixture{
		pool: pool, actor: uuid.NewString(), peer: uuid.NewString(), outsider: uuid.NewString(),
		pair: uuid.NewString(), otherPair: uuid.NewString(), message: uuid.NewString(),
		attached: uuid.NewString(), unattached: uuid.NewString(), storageKey: uuid.NewString(),
	}
	for i, seed := range []struct {
		query string
		args  []any
	}{
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be10actor','Actor','test','MEMBER')`, []any{fixture.actor}},
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be10peer','Peer','test','MEMBER')`, []any{fixture.peer}},
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be10outsider','Outsider','test','ADMINISTRATOR')`, []any{fixture.outsider}},
		{`INSERT INTO direct_messages (id,participant_one_id,participant_two_id) VALUES ($1,LEAST($2::uuid,$3::uuid),GREATEST($2::uuid,$3::uuid))`, []any{fixture.pair, fixture.actor, fixture.peer}},
		{`INSERT INTO direct_messages (id,participant_one_id,participant_two_id) VALUES ($1,LEAST($2::uuid,$3::uuid),GREATEST($2::uuid,$3::uuid))`, []any{fixture.otherPair, fixture.peer, fixture.outsider}},
		{`INSERT INTO direct_message_messages (id,direct_message_id,author_id,client_message_id,body) VALUES ($1,$2,$3,$4,'file')`, []any{fixture.message, fixture.pair, fixture.actor, uuid.NewString()}},
		{`INSERT INTO attachments (id,owner_id,direct_message_id,original_name,storage_key,byte_size,state,attached_at) VALUES ($1,$2,$3,'private.svg',$4,4,'ATTACHED',now())`, []any{fixture.attached, fixture.actor, fixture.pair, fixture.storageKey}},
		{`INSERT INTO attachments (id,owner_id,direct_message_id,original_name,storage_key,byte_size,state) VALUES ($1,$2,$3,'pending.svg',$4,4,'UNATTACHED')`, []any{fixture.unattached, fixture.actor, fixture.pair, uuid.NewString()}},
		{`INSERT INTO direct_message_attachments (message_id,attachment_id,position) VALUES ($1,$2,0)`, []any{fixture.message, fixture.attached}},
	} {
		if _, err := pool.Exec(ctx, seed.query, seed.args...); err != nil {
			t.Fatal(fmt.Sprintf("seed %d: %v", i, err))
		}
	}
	return fixture
}
