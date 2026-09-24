package connectsession

import "time"

type Event struct {
	EventID    string         `json:"event_id"`
	Kind       string         `json:"kind"`
	OccurredAt time.Time      `json:"occurred_at"`
	Payload    map[string]any `json:"payload"`
}

type Clock func() time.Time
type Identifier func() string

type ConnectionObserver interface {
	RealtimeConnectionOpened()
	ObserveRealtimeConnectionReady(time.Duration)
	RealtimeConnectionClosed()
}

const defaultSessionRevalidationInterval = 15 * time.Second
