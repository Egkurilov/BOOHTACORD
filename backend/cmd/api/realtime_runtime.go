package main

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	replayeventpostgres "voice-platform/backend/internal/realtime/replay_event/postgres"
	notifyleaserevocation "voice-platform/backend/internal/voice/notify_lease_revocation"
)

// startRealtimeServices attaches the durable hint journal before an outbox
// worker can mark a voice notification emitted.
func startRealtimeServices(database *pgxpool.Pool) (*eventhub.Hub, func()) {
	events := eventhub.New(64)
	events.SetJournal(replayeventpostgres.New(database))
	service := notifyleaserevocation.New(
		notifyleaserevocation.NewRepository(notifyleaserevocation.NewPoolDatabase(database)), events)
	stop := startVoiceLeaseRevocationNotificationWorker(context.Background(), service)
	return events, stop
}
