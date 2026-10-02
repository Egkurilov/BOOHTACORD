package renamepostgres

import (
	"context"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

func newRenameFixture(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	return pool
}

func seedRenameTopology(t *testing.T, pool *pgxpool.Pool) (actorID, firstCategoryID, secondCategoryID, channelID string) {
	t.Helper()
	actorID, firstCategoryID, secondCategoryID, channelID = uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	for _, seed := range []struct {
		statement string
		args      []any
	}{
		{`INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'qa02owner','Owner','test','ADMINISTRATOR')`, []any{actorID}},
		{`INSERT INTO channel_topology_state (singleton,revision) VALUES (TRUE,1)`, nil},
		{`INSERT INTO categories (id,name,position) VALUES ($1,'General',0)`, []any{firstCategoryID}},
		{`INSERT INTO categories (id,name,position) VALUES ($1,'Games',1)`, []any{secondCategoryID}},
		{`INSERT INTO channels (id,category_id,name,kind,position) VALUES ($1,$2,'Original','TEXT',0)`, []any{channelID, firstCategoryID}},
	} {
		if _, err := pool.Exec(context.Background(), seed.statement, seed.args...); err != nil {
			t.Fatal(err)
		}
	}
	return
}
