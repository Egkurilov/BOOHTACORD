package authorizedirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	authorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
)

const selectTarget = `
SELECT 1 FROM direct_messages dm
JOIN users one ON one.id = dm.participant_one_id
JOIN users two ON two.id = dm.participant_two_id
WHERE dm.id = $2
  AND $1::uuid IN (dm.participant_one_id, dm.participant_two_id)
  AND one.blocked_at IS NULL AND two.blocked_at IS NULL`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Authorize(ctx context.Context, input authorize.Input) error {
	var permitted int
	err := repository.database.QueryRow(ctx, selectTarget, input.ActorID, input.DirectMessageID).Scan(&permitted)
	if errors.Is(err, pgx.ErrNoRows) {
		return authorize.ErrTargetUnavailable
	}
	if err != nil {
		return fmt.Errorf("select direct message attachment target: %w", err)
	}
	return nil
}
