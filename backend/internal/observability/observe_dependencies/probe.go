package observedependencies

import (
	"context"
	"errors"
	"time"
	"voice-platform/backend/internal/lifecycle/periodic"
	incident "voice-platform/backend/internal/observability/observe_incidents"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

type SFU interface {
	Ping(context.Context) error
}

func Start(ctx context.Context, sfu SFU, space reserve.Space) *periodic.Worker {
	return periodic.Start(ctx, 15*time.Second, func(ctx context.Context) { Attempt(ctx, sfu, space) })
}
func Attempt(parent context.Context, sfu SFU, space reserve.Space) {
	ctx, cancel := context.WithTimeout(parent, 3*time.Second)
	started := time.Now()
	err := sfu.Ping(ctx)
	if err == nil {
		err = ctx.Err()
	}
	incident.Observe("livekit_probe", started, err)
	cancel()
	ctx, cancel = context.WithTimeout(parent, 3*time.Second)
	defer cancel()
	started = time.Now()
	snapshot, err := space.Snapshot(ctx)
	if err == nil {
		err = ctx.Err()
	}
	if err == nil && (snapshot.AvailableBytes < 0 || snapshot.TotalBytes < 0 || snapshot.AvailableBytes > snapshot.TotalBytes) {
		err = errors.New("invalid snapshot")
	}
	incident.Observe("storage_probe", started, err)
}
