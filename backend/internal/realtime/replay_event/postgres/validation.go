package replayeventpostgres

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

var ErrInvalidHint = errors.New("invalid durable realtime hint")

func validateHint(event eventhub.Event, recipients []string) error {
	if _, err := uuid.Parse(event.EventID); err != nil || event.OccurredAt.IsZero() || event.OccurredAt.After(time.Now().Add(time.Minute)) {
		return ErrInvalidHint
	}
	var required []string
	private := false
	switch event.Kind {
	case "message.created", "message.updated", "message.deleted":
		required = []string{"channel_id", "message_id"}
	case "direct_message.message_created", "direct_message.message_updated", "direct_message.message_deleted":
		required, private = []string{"direct_message_id", "message_id"}, true
	case "voice.lease_revoked":
		required, private = []string{"lease_id", "reason"}, true
	case "channel.updated", "guild.profile.updated":
		required = []string{"revision"}
	default:
		return ErrInvalidHint
	}
	if len(recipients) > 0 != private || len(event.Payload) < len(required) || len(event.Payload) > len(required)+1 {
		return ErrInvalidHint
	}
	for _, accountID := range recipients {
		if _, err := uuid.Parse(accountID); err != nil {
			return ErrInvalidHint
		}
	}
	for key, value := range event.Payload {
		switch key {
		case "channel_id", "message_id", "direct_message_id", "lease_id":
			identifier, ok := value.(string)
			if !ok {
				return ErrInvalidHint
			}
			if _, err := uuid.Parse(identifier); err != nil {
				return ErrInvalidHint
			}
		case "revision":
			switch number := value.(type) {
			case int:
				if number < 1 {
					return ErrInvalidHint
				}
			case int64:
				if number < 1 {
					return ErrInvalidHint
				}
			case float64:
				if number < 1 || number != float64(int64(number)) {
					return ErrInvalidHint
				}
			default:
				return ErrInvalidHint
			}
		case "reason":
			if !allowedReason(value) {
				return ErrInvalidHint
			}
		default:
			return fmt.Errorf("%w: unexpected field", ErrInvalidHint)
		}
	}
	for _, key := range required {
		if _, ok := event.Payload[key]; !ok {
			return ErrInvalidHint
		}
	}
	if len(event.Payload) == len(required)+1 {
		if _, ok := event.Payload["revision"]; !ok {
			return ErrInvalidHint
		}
		if event.Kind == "channel.updated" || event.Kind == "guild.profile.updated" || event.Kind == "voice.lease_revoked" {
			return ErrInvalidHint
		}
	}
	return nil
}

func allowedReason(value any) bool {
	reason, ok := value.(string)
	if !ok {
		return false
	}
	switch reason {
	case "TRANSFER", "KICK", "CHANNEL_CLOSED", "SESSION_REVOKED", "BANNED", "LOGOUT", "VOLUNTARY_LEAVE":
		return true
	default:
		return false
	}
}
