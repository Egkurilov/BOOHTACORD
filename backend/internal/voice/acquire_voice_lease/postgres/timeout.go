package acquirevoiceleasepostgres

import (
	"context"
	acquire "voice-platform/backend/internal/voice/acquire_voice_lease"
)

func (transaction poolTransaction) CheckVoiceTimeout(ctx context.Context, account string) error {
	var denied bool
	err := transaction.transaction.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM voice_timeouts
 WHERE user_id=$1 AND expires_at>clock_timestamp())`, account).Scan(&denied)
	if err != nil {
		return err
	}
	if denied {
		return acquire.ErrVoiceTimeout
	}
	return nil
}
