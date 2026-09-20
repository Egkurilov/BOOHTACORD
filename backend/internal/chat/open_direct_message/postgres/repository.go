package opendirectmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	opendirectmessage "voice-platform/backend/internal/chat/open_direct_message"
)

const openDirectMessage = `
WITH active_pair AS (
    SELECT LEAST($1::uuid, $2::uuid) AS participant_one_id, GREATEST($1::uuid, $2::uuid) AS participant_two_id
    WHERE $1::uuid <> $2::uuid
      AND (SELECT count(*) FROM users WHERE id = ANY(ARRAY[$1::uuid, $2::uuid]) AND blocked_at IS NULL) = 2
), opened AS (
    INSERT INTO direct_messages (id, participant_one_id, participant_two_id)
    SELECT $3::uuid, participant_one_id, participant_two_id FROM active_pair
    ON CONFLICT (participant_one_id, participant_two_id) DO UPDATE SET participant_one_id = EXCLUDED.participant_one_id
    RETURNING id::text, participant_one_id::text, participant_two_id::text, created_at
)
SELECT * FROM opened`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Open(context context.Context, request opendirectmessage.Request) (opendirectmessage.Result, error) {
	var result opendirectmessage.Result
	err := repository.database.QueryRow(context, openDirectMessage, request.ActorID, request.ParticipantID, request.ID).Scan(
		&result.ID, &result.ParticipantOneID, &result.ParticipantTwoID, &result.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return opendirectmessage.Result{}, opendirectmessage.ErrParticipantUnavailable
	}
	if err != nil {
		return opendirectmessage.Result{}, fmt.Errorf("open direct message: %w", err)
	}
	return result, nil
}
