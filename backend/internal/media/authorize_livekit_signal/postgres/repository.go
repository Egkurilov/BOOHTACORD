package authorizelivekitsignalpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
)

const selectAdmissibleLease = `
SELECT 1
FROM voice_leases AS lease
JOIN sessions AS session ON session.token_digest = lease.session_token_digest
JOIN channels AS channel ON channel.id = lease.channel_id
JOIN users AS account ON account.id = lease.user_id
WHERE lease.id = $1
  AND lease.channel_id = $2
  AND lease.revoked_at IS NULL
  AND session.revoked_at IS NULL
  AND channel.kind = 'VOICE'
  AND channel.archived_at IS NULL
  AND channel.admission_closed_at IS NULL
  AND account.blocked_at IS NULL`

type Row interface{ Scan(...any) error }

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Admit(context context.Context, leaseID, channelID string) error {
	var ignored int
	err := repository.database.QueryRow(context, selectAdmissibleLease, leaseID, channelID).Scan(&ignored)
	if errors.Is(err, pgx.ErrNoRows) {
		return authorizelivekitsignal.ErrDenied
	}
	if err != nil {
		return fmt.Errorf("select admissible livekit lease: %w", err)
	}
	return nil
}
