package senddirectmessagepostgres

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

type dmFixture struct {
	pool                                               *pgxpool.Pool
	actor, peer, outsider, pair, otherPair, attachment string
}

func newDMFixture(t *testing.T) dmFixture {
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
	if address == nil || !address.IsLoopback() {
		t.Fatal("test database must use a loopback IP address")
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
	schema := "be09_" + strings.ReplaceAll(uuid.NewString(), "-", "")
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
	fixture := dmFixture{pool: pool, actor: "11111111-1111-4111-8111-111111111111", peer: "22222222-2222-4222-8222-222222222222", outsider: "33333333-3333-4333-8333-333333333333", pair: uuid.NewString(), otherPair: uuid.NewString(), attachment: uuid.NewString()}
	seeds := []struct {
		query string
		args  []any
	}{
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be09actor','Actor','test','MEMBER')`, []any{fixture.actor}},
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be09peer','Peer','test','MEMBER')`, []any{fixture.peer}},
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be09outsider','Outsider','test','ADMINISTRATOR')`, []any{fixture.outsider}},
		{`INSERT INTO direct_messages (id,participant_one_id,participant_two_id) VALUES ($1,$2,$3)`, []any{fixture.pair, fixture.actor, fixture.peer}},
		{`INSERT INTO direct_messages (id,participant_one_id,participant_two_id) VALUES ($1,$2,$3)`, []any{fixture.otherPair, fixture.peer, fixture.outsider}},
		{`INSERT INTO attachments (id,owner_id,direct_message_id,original_name,storage_key,byte_size,state) VALUES ($1,$2,$3,'x.txt',$4,1,'UNATTACHED')`, []any{fixture.attachment, fixture.actor, fixture.pair, uuid.NewString()}},
	}
	for i, seed := range seeds {
		if _, err := pool.Exec(ctx, seed.query, seed.args...); err != nil {
			t.Fatal(fmt.Sprintf("seed %d: %v", i, err))
		}
	}
	return fixture
}
