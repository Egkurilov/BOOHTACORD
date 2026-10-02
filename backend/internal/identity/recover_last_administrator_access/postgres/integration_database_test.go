package recoverlastadministratoraccesspostgres

import (
	"context"
	"crypto/sha256"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

func newRecoveryPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	return pool
}

func seedRecoveryAccess(t *testing.T, pool *pgxpool.Pool, userID string) (string, [sha256.Size]byte) {
	t.Helper()
	ctx := context.Background()
	categoryID, channelID, leaseID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	digest := sha256.Sum256([]byte("synthetic recovery session"))
	for _, fixture := range []struct {
		statement string
		args      []any
	}{
		{`INSERT INTO sessions (token_digest, user_id) VALUES ($1, $2)`, []any{digest[:], userID}},
		{`INSERT INTO categories (id, name, position) VALUES ($1, 'QA recovery', 0)`, []any{categoryID}},
		{`INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'QA voice', 'VOICE', 0)`, []any{channelID, categoryID}},
		{`INSERT INTO voice_leases (id, user_id, channel_id, session_token_digest) VALUES ($1, $2, $3, $4)`, []any{leaseID, userID, channelID, digest[:]}},
	} {
		if _, err := pool.Exec(ctx, fixture.statement, fixture.args...); err != nil {
			t.Fatal(err)
		}
	}
	return leaseID, digest
}
