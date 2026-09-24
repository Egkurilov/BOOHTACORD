package resolvedirectmessagerecipientspostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

const selectCurrentRecipients = `
SELECT dm.participant_one_id::text, dm.participant_two_id::text,
       first_user.blocked_at IS NULL, second_user.blocked_at IS NULL
FROM direct_messages dm
JOIN users first_user ON first_user.id = dm.participant_one_id
JOIN users second_user ON second_user.id = dm.participant_two_id
JOIN users actor ON actor.id = $2::uuid
WHERE dm.id = $1::uuid
  AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
  AND actor.blocked_at IS NULL`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

// Resolve rechecks the canonical DM pair after a successful mutation and
// suppresses events to accounts that can no longer hold an active session.
func (repository Repository) Resolve(ctx context.Context, directMessageID, actorID string) ([]string, error) {
	var first, second string
	var firstActive, secondActive bool
	err := repository.database.QueryRow(ctx, selectCurrentRecipients, directMessageID, actorID).Scan(&first, &second, &firstActive, &secondActive)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("resolve current direct message recipients: %w", err)
	}
	recipients := make([]string, 0, 2)
	if firstActive {
		recipients = append(recipients, first)
	}
	if secondActive {
		recipients = append(recipients, second)
	}
	return recipients, nil
}
