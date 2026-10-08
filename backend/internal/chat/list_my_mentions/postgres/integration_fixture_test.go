package listmymentionspostgres

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

type mentionsFixture struct {
	pool                                              *pgxpool.Pool
	caller, author, outsider, channel, ownDM, otherDM string
}

func newMentionsFixture(t *testing.T) mentionsFixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal("migrate:", err)
	}
	f := mentionsFixture{pool: pool, caller: uuid.NewString(), author: uuid.NewString(), outsider: uuid.NewString(), channel: uuid.NewString(), ownDM: uuid.NewString(), otherDM: uuid.NewString()}
	seeds := []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'mentioncaller','Caller','test','MEMBER')`, []any{f.caller}},
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'mentionauthor','Author','test','MEMBER')`, []any{f.author}},
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'mentionoutsider','Outsider','test','MEMBER')`, []any{f.outsider}},
		{`INSERT INTO categories (id,name,position) VALUES ($1,'General',0)`, []any{uuid.NewString()}},
	}
	category := seeds[3].args[0]
	seeds = append(seeds,
		struct {
			sql  string
			args []any
		}{`INSERT INTO channels (id,category_id,name,kind,position) VALUES ($1,$2,'Text','TEXT',0)`, []any{f.channel, category}},
		struct {
			sql  string
			args []any
		}{`INSERT INTO direct_messages (id,participant_one_id,participant_two_id) VALUES ($1,$2,$3)`, []any{f.ownDM, f.caller, f.author}},
		struct {
			sql  string
			args []any
		}{`INSERT INTO direct_messages (id,participant_one_id,participant_two_id) VALUES ($1,$2,$3)`, []any{f.otherDM, f.author, f.outsider}},
	)
	for _, seed := range seeds {
		if _, err := pool.Exec(ctx, seed.sql, seed.args...); err != nil {
			t.Fatal("seed mentions fixture:", err)
		}
	}
	return f
}
