package finalizeclosedvoicechannel

import (
	"context"
	"errors"
	"fmt"
)

var ErrInvalidLimit = errors.New("invalid voice channel finalization limit")

type Store interface {
	Candidates(context.Context, int, string) ([]string, error)
	Finalize(context.Context, string) (int64, error)
}

type Presence interface {
	CountRoomParticipants(context.Context, string) (int, error)
}

type Publisher interface {
	PublishTopologyRevision(int64)
}

type Service struct {
	store     Store
	presence  Presence
	publisher Publisher
	cursor    string
}

func New(store Store, presence Presence, publisher Publisher) *Service {
	return &Service{store: store, presence: presence, publisher: publisher}
}

func (service *Service) Run(ctx context.Context, limit int) (int, error) {
	if limit < 1 || limit > 100 {
		return 0, ErrInvalidLimit
	}
	candidates, err := service.store.Candidates(ctx, limit, service.cursor)
	if err != nil {
		return 0, fmt.Errorf("list closed voice channel candidates: %w", err)
	}
	if len(candidates) == 0 && service.cursor != "" {
		service.cursor = ""
		candidates, err = service.store.Candidates(ctx, limit, "")
		if err != nil {
			return 0, fmt.Errorf("restart closed voice channel scan: %w", err)
		}
	}
	finalized := 0
	for _, channelID := range candidates {
		service.cursor = channelID
		participants, err := service.presence.CountRoomParticipants(ctx, channelID)
		if err != nil {
			return finalized, fmt.Errorf("confirm private voice room presence: %w", err)
		}
		if participants != 0 {
			continue
		}
		revision, err := service.store.Finalize(ctx, channelID)
		if err != nil {
			return finalized, fmt.Errorf("finalize closed voice channel: %w", err)
		}
		if revision == 0 {
			continue
		}
		service.publisher.PublishTopologyRevision(revision)
		finalized++
	}
	return finalized, nil
}
