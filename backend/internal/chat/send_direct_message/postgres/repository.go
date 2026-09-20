package senddirectmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
)

const insertDirectMessage = `
WITH active_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $2
      AND $3::uuid IN (dm.participant_one_id, dm.participant_two_id)
      AND EXISTS (SELECT 1 FROM users WHERE id = dm.participant_one_id AND blocked_at IS NULL)
      AND EXISTS (SELECT 1 FROM users WHERE id = dm.participant_two_id AND blocked_at IS NULL)
), inserted AS (
    INSERT INTO direct_message_messages (id, direct_message_id, author_id, client_message_id, body, reply_to_id)
    SELECT $1::uuid, active_pair.id, $3::uuid, $4::uuid, $5, $6::uuid FROM active_pair
    WHERE $6::uuid IS NULL OR EXISTS (
        SELECT 1 FROM direct_message_messages reply
        WHERE reply.id = $6::uuid AND reply.direct_message_id = active_pair.id
    )
    ON CONFLICT (author_id, direct_message_id, client_message_id) DO UPDATE SET client_message_id = EXCLUDED.client_message_id
    RETURNING id::text, direct_message_id::text, author_id::text, client_message_id::text, body, COALESCE(reply_to_id::text, ''), revision, created_at
)
SELECT * FROM inserted`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Send(context context.Context, request senddirectmessage.Request) (senddirectmessage.Result, error) {
	var result senddirectmessage.Result
	var replyTo any
	if request.ReplyToID != "" {
		replyTo = request.ReplyToID
	}
	err := repository.database.QueryRow(context, insertDirectMessage, request.ID, request.DirectMessageID, request.ActorID, request.ClientMessageID, request.Body, replyTo).Scan(
		&result.ID, &result.DirectMessageID, &result.AuthorID, &result.ClientMessageID, &result.Body, &result.ReplyToID, &result.Revision, &result.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return senddirectmessage.Result{}, senddirectmessage.ErrDirectMessageUnavailable
	}
	if err != nil {
		return senddirectmessage.Result{}, fmt.Errorf("insert direct message: %w", err)
	}
	return result, nil
}
