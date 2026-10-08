package changemessagereactionpostgres

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

type socialFixture struct {
	pool                                                                                                                *pgxpool.Pool
	admin, a, b, outsider, blocked, channel, archived, voice, message, second, dm, dmMessage, foreignDM, foreignMessage string
}

func newSocialFixture(t *testing.T) socialFixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), 90*time.Second)
	t.Cleanup(cancel)
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	f := socialFixture{pool: pool, admin: uuid.NewString(), a: uuid.NewString(), b: uuid.NewString(), outsider: uuid.NewString(), blocked: uuid.NewString(), channel: uuid.NewString(), archived: uuid.NewString(), voice: uuid.NewString(), message: uuid.NewString(), second: uuid.NewString(), dm: uuid.NewString(), dmMessage: uuid.NewString(), foreignDM: uuid.NewString(), foreignMessage: uuid.NewString()}
	f.exec(t, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'admin','Admin','test-only','ADMINISTRATOR'),($2,'membera','A','test-only','MEMBER'),($3,'memberb','B','test-only','MEMBER'),($4,'outsider','Outside','test-only','MEMBER'),($5,'blocked','Blocked','test-only','MEMBER')`, f.admin, f.a, f.b, f.outsider, f.blocked)
	f.exec(t, "UPDATE users SET blocked_at=now() WHERE id=$1", f.blocked)
	category := uuid.NewString()
	f.exec(t, "INSERT INTO categories(id,name,position) VALUES($1,'Social tests',0)", category)
	f.exec(t, `INSERT INTO channels(id,category_id,name,kind,position,archived_at) VALUES($1,$4,'Text','TEXT',0,NULL),($2,$4,'Archive','TEXT',1,now()),($3,$4,'Voice','VOICE',2,NULL)`, f.channel, f.archived, f.voice, category)
	f.exec(t, `INSERT INTO messages(id,channel_id,author_id,client_message_id,body) VALUES($1,$3,$4,$5,'synthetic'),($2,$3,$4,$6,'synthetic')`, f.message, f.second, f.channel, f.a, uuid.NewString(), uuid.NewString())
	first, second := f.a, f.b
	if first > second {
		first, second = second, first
	}
	f.exec(t, "INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES($1,$2,$3)", f.dm, first, second)
	first, second = f.a, f.outsider
	if first > second {
		first, second = second, first
	}
	f.exec(t, "INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES($1,$2,$3)", f.foreignDM, first, second)
	f.exec(t, `INSERT INTO direct_message_messages(id,direct_message_id,author_id,client_message_id,body) VALUES($1,$2,$5,$6,'synthetic'),($3,$4,$5,$7,'synthetic')`, f.dmMessage, f.dm, f.foreignMessage, f.foreignDM, f.a, uuid.NewString(), uuid.NewString())
	return f
}
func (f socialFixture) exec(t *testing.T, sql string, args ...any) {
	t.Helper()
	if _, err := f.pool.Exec(t.Context(), sql, args...); err != nil {
		t.Fatal(err)
	}
}
func (f socialFixture) count(t *testing.T, table, message string) int {
	t.Helper()
	var count int
	if err := f.pool.QueryRow(t.Context(), "SELECT count(*) FROM "+table+" WHERE message_id=$1", message).Scan(&count); err != nil {
		t.Fatal(err)
	}
	return count
}
