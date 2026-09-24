package eventhub

import (
	"context"
	"errors"
)

var ErrJournalUnavailable = errors.New("realtime journal unavailable")

type Journal interface {
	Append(context.Context, Event, []string, string) error
	Replay(context.Context, string, string, string, int) ([]Event, error)
	Authorize(context.Context, string, Event) (bool, error)
}

func (hub *Hub) SetJournal(journal Journal) {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	hub.journal = journal
}

func (hub *Hub) BootEpoch() string {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	return hub.bootEpoch
}

func (hub *Hub) ContinuityAt(epoch string) bool {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	return hub.journal != nil && !hub.broken && hub.bootEpoch == epoch
}

func (hub *Hub) Replay(ctx context.Context, accountID, after string, limit int) ([]Event, error) {
	hub.mu.Lock()
	journal, broken, epoch := hub.journal, hub.broken, hub.bootEpoch
	hub.mu.Unlock()
	if journal == nil || broken {
		return nil, ErrJournalUnavailable
	}
	events, err := journal.Replay(ctx, accountID, after, epoch, limit)
	hub.mu.Lock()
	continuityLost := hub.broken || hub.bootEpoch != epoch
	hub.mu.Unlock()
	if continuityLost {
		return nil, ErrJournalUnavailable
	}
	return events, err
}

func (hub *Hub) Authorize(ctx context.Context, accountID string, event Event) (bool, error) {
	hub.mu.Lock()
	journal, broken := hub.journal, hub.broken
	hub.mu.Unlock()
	if journal == nil || broken {
		return false, ErrJournalUnavailable
	}
	return journal.Authorize(ctx, accountID, event)
}
