package archivereadonlytextpostgres

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

type archiveFixture struct {
	pool                                                                   *pgxpool.Pool
	admin, member, blocked, channel, voice, deleted, message, client, file string
}

func newArchiveFixture(t *testing.T) archiveFixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), 45*time.Second)
	t.Cleanup(cancel)
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	f := archiveFixture{pool: pool, admin: uuid.NewString(), member: uuid.NewString(), blocked: uuid.NewString(), channel: uuid.NewString(), voice: uuid.NewString(), deleted: uuid.NewString(), message: uuid.NewString(), client: uuid.NewString(), file: uuid.NewString()}
	exec := func(q string, args ...any) {
		t.Helper()
		if _, err := pool.Exec(ctx, q, args...); err != nil {
			t.Fatal(err)
		}
	}
	exec("INSERT INTO channel_topology_state(singleton,revision) VALUES(TRUE,1)")
	exec("INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'admin','Admin','test-only','ADMINISTRATOR'),($2,'reader','Reader','test-only','MEMBER'),($3,'blocked','Blocked','test-only','MEMBER')", f.admin, f.member, f.blocked)
	exec("UPDATE users SET blocked_at=now() WHERE id=$1", f.blocked)
	category := uuid.NewString()
	exec("INSERT INTO categories(id,name,position) VALUES($1,'Archive tests',0)", category)
	exec("INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$4,'Text','TEXT',0),($2,$4,'Voice','VOICE',1),($3,$4,'Deleted','TEXT',2)", f.channel, f.voice, f.deleted, category)
	exec("UPDATE channels SET archived_at=now() WHERE id=$1", f.deleted)
	exec("INSERT INTO messages(id,channel_id,author_id,client_message_id,body) VALUES($1,$2,$3,$4,'orbit history')", f.message, f.channel, f.member, f.client)
	exec("INSERT INTO attachments(id,channel_id,owner_id,storage_key,original_name,byte_size,state,attached_at) VALUES($1,$2,$3,$4,'archive.txt',12,'ATTACHED',now())", f.file, f.channel, f.member, uuid.NewString())
	exec("INSERT INTO message_attachments(message_id,attachment_id,position) VALUES($1,$2,0)", f.message, f.file)
	return f
}
func (f archiveFixture) revision(t *testing.T) int64 {
	t.Helper()
	var v int64
	if err := f.pool.QueryRow(t.Context(), "SELECT revision FROM channel_topology_state WHERE singleton").Scan(&v); err != nil {
		t.Fatal(err)
	}
	return v
}
