package replayeventpostgres

import (
	"context"
	"fmt"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func (repository Repository) Authorize(ctx context.Context, accountID string, event eventhub.Event) (bool, error) {
	var statement, resourceID string
	switch event.Kind {
	case "message.created", "message.updated", "message.deleted":
		statement = `SELECT EXISTS (SELECT 1 FROM channels c JOIN users u ON u.id=$1::uuid
            WHERE c.id=$2::uuid AND c.kind='TEXT' AND c.archived_at IS NULL AND u.blocked_at IS NULL)`
		resourceID, _ = event.Payload["channel_id"].(string)
	case "direct_message.message_created", "direct_message.message_updated", "direct_message.message_deleted":
		statement = `SELECT EXISTS (SELECT 1 FROM direct_messages dm JOIN users u ON u.id=$1::uuid
            WHERE dm.id=$2::uuid AND u.blocked_at IS NULL
            AND u.id IN (dm.participant_one_id,dm.participant_two_id))`
		resourceID, _ = event.Payload["direct_message_id"].(string)
	case "voice.lease_revoked":
		statement = `SELECT EXISTS (SELECT 1 FROM voice_leases vl JOIN users u ON u.id=$1::uuid
            WHERE vl.id=$2::uuid AND vl.user_id=u.id AND u.blocked_at IS NULL)`
		resourceID, _ = event.Payload["lease_id"].(string)
	case "channel.updated", "guild.profile.updated":
		statement = `SELECT EXISTS (SELECT 1 FROM users u WHERE u.id=$1::uuid AND u.blocked_at IS NULL)`
	case "member.profile.updated":
		statement = `SELECT EXISTS (SELECT 1 FROM users viewer JOIN users member ON member.id=$2::uuid WHERE viewer.id=$1::uuid AND viewer.blocked_at IS NULL AND member.blocked_at IS NULL)`
		resourceID, _ = event.Payload["user_id"].(string)
	default:
		return false, nil
	}
	var allowed bool
	var err error
	if resourceID == "" {
		err = repository.database.QueryRow(ctx, statement, accountID).Scan(&allowed)
	} else {
		err = repository.database.QueryRow(ctx, statement, accountID, resourceID).Scan(&allowed)
	}
	if err != nil {
		return false, fmt.Errorf("authorize realtime replay hint: %w", err)
	}
	return allowed, nil
}
