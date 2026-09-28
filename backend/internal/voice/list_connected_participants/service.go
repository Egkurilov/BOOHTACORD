package listconnectedparticipants

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"time"

	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

var ErrPresenceUnavailable = errors.New("private voice presence unavailable")

type Lease struct{ ID, AccountID, DisplayName string }
type Channel struct {
	ID     string
	Leases []Lease
}
type Participant struct {
	AccountID     string `json:"account_id"`
	DisplayName   string `json:"display_name"`
	ScreenSharing bool   `json:"screen_sharing"`
}
type ChannelRoster struct {
	ChannelID    string        `json:"channel_id"`
	Participants []Participant `json:"participants"`
}
type Result struct {
	Channels []ChannelRoster `json:"channels"`
}

type Repository interface {
	ListVisible(context.Context, string) ([]Channel, error)
}
type Presence interface {
	SnapshotRooms(context.Context, []string) (map[string][]snapshotlivekitpresence.ConnectedLease, error)
}
type SnapshotObserver interface {
	ObserveVoiceRosterSnapshot(time.Duration, int, bool)
}
type Service struct {
	repository Repository
	presence   Presence
	observer   SnapshotObserver
}

func New(repository Repository, presence Presence, observers ...SnapshotObserver) Service {
	service := Service{repository: repository, presence: presence}
	if len(observers) > 0 {
		service.observer = observers[0]
	}
	return service
}

func (service Service) List(ctx context.Context, actorID string) (Result, error) {
	channels, err := service.repository.ListVisible(ctx, actorID)
	if err != nil {
		return Result{}, fmt.Errorf("list visible voice channels: %w", err)
	}
	result := Result{Channels: make([]ChannelRoster, 0, len(channels))}
	ids := make([]string, 0, len(channels))
	for _, channel := range channels {
		ids = append(ids, channel.ID)
	}
	started := time.Now()
	connected, err := service.presence.SnapshotRooms(ctx, ids)
	if service.observer != nil {
		service.observer.ObserveVoiceRosterSnapshot(time.Since(started), len(ids), err != nil)
	}
	if err != nil {
		return Result{}, fmt.Errorf("%w: %v", ErrPresenceUnavailable, err)
	}
	// A lease or account may be revoked while the private SFU snapshot is read.
	channels, err = service.repository.ListVisible(ctx, actorID)
	if err != nil {
		return Result{}, fmt.Errorf("recheck visible voice channels: %w", err)
	}
	for _, channel := range channels {
		current := ChannelRoster{ChannelID: channel.ID, Participants: make([]Participant, 0)}
		active := make(map[string]Lease, len(channel.Leases))
		for _, lease := range channel.Leases {
			active[lease.ID] = lease
		}
		seen := make(map[string]bool)
		for _, presence := range connected[channel.ID] {
			lease, valid := active[presence.LeaseID]
			if !valid || seen[lease.AccountID] {
				continue
			}
			seen[lease.AccountID] = true
			current.Participants = append(current.Participants, Participant{
				AccountID: lease.AccountID, DisplayName: lease.DisplayName, ScreenSharing: presence.ScreenSharing,
			})
		}
		sort.Slice(current.Participants, func(i, j int) bool { return current.Participants[i].AccountID < current.Participants[j].AccountID })
		result.Channels = append(result.Channels, current)
	}
	return result, nil
}
