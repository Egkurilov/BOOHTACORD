package acquirevoiceleasepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	acquirevoicelease "voice-platform/backend/internal/voice/acquire_voice_lease"
)

func verifyActiveSession(transaction Transaction, context context.Context, digest []byte, actorID string) error {
	var value []byte
	err := transaction.QueryRow(context, selectActiveSession, digest, actorID).Scan(&value)
	if errors.Is(err, pgx.ErrNoRows) {
		return acquirevoicelease.ErrSessionUnavailable
	}
	if err != nil {
		return fmt.Errorf("validate voice session: %w", err)
	}
	return nil
}

func verifyVoiceChannel(transaction Transaction, context context.Context, channelID string) error {
	var value string
	err := transaction.QueryRow(context, selectVoiceChannel, channelID).Scan(&value)
	if errors.Is(err, pgx.ErrNoRows) {
		return acquirevoicelease.ErrVoiceChannelUnavailable
	}
	if err != nil {
		return fmt.Errorf("validate voice channel: %w", err)
	}
	return nil
}
