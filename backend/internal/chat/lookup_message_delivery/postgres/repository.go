package deliverypostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	delivery "voice-platform/backend/internal/chat/lookup_message_delivery"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool: pool} }
func (r Repository) Lookup(ctx context.Context, input delivery.Input) (*string, error) {
	statement := `SELECT (SELECT id::text FROM messages WHERE channel_id=$1 AND author_id=$2 AND client_message_id=$3)
 FROM channels WHERE id=$1 AND kind='TEXT' AND archived_at IS NULL`
	if input.Direct {
		statement = `SELECT (SELECT id::text FROM direct_message_messages WHERE direct_message_id=$1 AND author_id=$2 AND client_message_id=$3)
 FROM direct_messages WHERE id=$1 AND $2::uuid IN(participant_one_id,participant_two_id)`
	}
	var id *string
	err := r.pool.QueryRow(ctx, statement, input.ConversationID, input.ActorID, input.ClientMessageID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, delivery.ErrUnavailable
	}
	return id, err
}
