package guildfixture

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

type Fixture struct {
	Context               context.Context
	Pool                  *pgxpool.Pool
	Admin, Channel, Voice string
}

func New(t *testing.T) Fixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), 30*time.Second)
	t.Cleanup(cancel)
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	f := Fixture{Context: ctx, Pool: pool, Admin: uuid.NewString(), Channel: uuid.NewString(), Voice: uuid.NewString()}
	statements := []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO users(id,login,display_name,role,password_hash) VALUES($1,'owner','Owner','ADMINISTRATOR','test-hash')`, []any{f.Admin}},
		{`INSERT INTO bootstrap_state(singleton,administrator_id) VALUES(TRUE,$1) ON CONFLICT(singleton) DO UPDATE SET administrator_id=$1`, []any{f.Admin}},
		{`INSERT INTO channel_topology_state(singleton,revision) VALUES(TRUE,1) ON CONFLICT(singleton) DO NOTHING`, nil},
		{`INSERT INTO categories(id,name,position) VALUES($1,'General',0)`, []any{uuid.NewString()}},
		{`INSERT INTO channels(id,category_id,name,kind,position) SELECT $1,id,'Text','TEXT',0 FROM categories`, []any{f.Channel}},
		{`INSERT INTO channels(id,category_id,name,kind,position) SELECT $1,id,'Voice','VOICE',1 FROM categories`, []any{f.Voice}},
	}
	for _, s := range statements {
		if _, err := pool.Exec(ctx, s.sql, s.args...); err != nil {
			t.Fatal(err)
		}
	}
	return f
}
