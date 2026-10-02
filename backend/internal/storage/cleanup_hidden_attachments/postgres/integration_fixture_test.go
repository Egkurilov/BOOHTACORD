package cleanuphiddenattachmentspostgres

import (
	"context"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

type fixture struct {
	pool                                                   *pgxpool.Pool
	owner, channel, dm, textDead, textLive, dmDead, dmLive string
	keys                                                   map[string]string
}

func newFixture(t *testing.T) fixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackOrLocalhost)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	f := fixture{pool: pool, owner: uuid.NewString(), channel: uuid.NewString(), dm: uuid.NewString(), textDead: uuid.NewString(), textLive: uuid.NewString(), dmDead: uuid.NewString(), dmLive: uuid.NewString(), keys: map[string]string{}}
	peer, category := uuid.NewString(), uuid.NewString()
	for _, row := range []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be12owner','Owner','test','MEMBER')`, []any{f.owner}},
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'be12peer','Peer','test','MEMBER')`, []any{peer}},
		{`INSERT INTO categories (id,name,position) VALUES ($1,'Test',0)`, []any{category}},
		{`INSERT INTO channels (id,category_id,name,kind,position) VALUES ($1,$2,'Text','TEXT',0)`, []any{f.channel, category}},
		{`INSERT INTO direct_messages (id,participant_one_id,participant_two_id) VALUES ($1,LEAST($2::uuid,$3::uuid),GREATEST($2::uuid,$3::uuid))`, []any{f.dm, f.owner, peer}},
		{`INSERT INTO messages (id,channel_id,author_id,client_message_id,body,deleted_at) VALUES ($1,$2,$3,$4,'',now())`, []any{f.textDead, f.channel, f.owner, uuid.NewString()}},
		{`INSERT INTO messages (id,channel_id,author_id,client_message_id,body) VALUES ($1,$2,$3,$4,'live')`, []any{f.textLive, f.channel, f.owner, uuid.NewString()}},
		{`INSERT INTO direct_message_messages (id,direct_message_id,author_id,client_message_id,body,deleted_at) VALUES ($1,$2,$3,$4,'',now())`, []any{f.dmDead, f.dm, f.owner, uuid.NewString()}},
		{`INSERT INTO direct_message_messages (id,direct_message_id,author_id,client_message_id,body) VALUES ($1,$2,$3,$4,'live')`, []any{f.dmLive, f.dm, f.owner, uuid.NewString()}},
	} {
		if _, err := pool.Exec(ctx, row.sql, row.args...); err != nil {
			t.Fatal(err)
		}
	}
	for _, item := range []struct{ name, target, message, table string }{
		{"text_dead", f.channel, f.textDead, "message_attachments"}, {"text_live", f.channel, f.textLive, "message_attachments"},
		{"dm_dead", f.dm, f.dmDead, "direct_message_attachments"}, {"dm_live", f.dm, f.dmLive, "direct_message_attachments"},
	} {
		id, key := uuid.NewString(), uuid.NewString()
		f.keys[item.name] = key
		column := "channel_id"
		if item.table == "direct_message_attachments" {
			column = "direct_message_id"
		}
		if _, err := pool.Exec(ctx, `INSERT INTO attachments (id,owner_id,`+column+`,original_name,storage_key,byte_size,state,attached_at) VALUES ($1,$2,$3,'private.bin',$4,4,'ATTACHED',now())`, id, f.owner, item.target, key); err != nil {
			t.Fatal(err)
		}
		if _, err := pool.Exec(ctx, `INSERT INTO `+item.table+` (message_id,attachment_id,position) VALUES ($1,$2,0)`, item.message, id); err != nil {
			t.Fatal(err)
		}
	}
	return f
}
