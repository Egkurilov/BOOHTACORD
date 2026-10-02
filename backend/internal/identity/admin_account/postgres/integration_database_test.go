package adminpostgres

import (
	"context"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

type adminFixture struct {
	pool          *pgxpool.Pool
	first, second string
}

func newAdminFixture(t *testing.T) adminFixture {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	fixture := adminFixture{pool: pool, first: uuid.NewString(), second: uuid.NewString()}
	for _, seed := range []struct{ id, login string }{{fixture.first, "qa02first"}, {fixture.second, "qa02second"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,$2,'Administrator','test','ADMINISTRATOR')`, seed.id, seed.login); err != nil {
			t.Fatal(err)
		}
	}
	return fixture
}
