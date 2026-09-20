package sessionpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/authenticate_session"
)

const selectActivePrincipal = `
SELECT u.id::text, u.role
FROM sessions s
JOIN users u ON u.id = s.user_id
WHERE s.token_digest = $1
  AND s.revoked_at IS NULL
  AND u.blocked_at IS NULL`

type Row interface {
	Scan(...any) error
}

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct {
	database Database
}

func New(database Database) Repository {
	return Repository{database: database}
}

func (repository Repository) FindActive(context context.Context, digest [sha256.Size]byte) (authenticatesession.Principal, error) {
	var principal authenticatesession.Principal
	err := repository.database.QueryRow(context, selectActivePrincipal, digest[:]).Scan(&principal.AccountID, &principal.Role)
	if errors.Is(err, pgx.ErrNoRows) {
		return authenticatesession.Principal{}, authenticatesession.ErrSessionNotFound
	}
	if err != nil {
		return authenticatesession.Principal{}, fmt.Errorf("select active session: %w", err)
	}
	return principal, nil
}
