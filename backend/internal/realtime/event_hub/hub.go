package eventhub

import (
	"sync"
	"time"
)

type Event struct {
	EventID    string         `json:"event_id"`
	Kind       string         `json:"kind"`
	OccurredAt time.Time      `json:"occurred_at"`
	Payload    map[string]any `json:"payload"`
}

type Hub struct {
	mu          sync.Mutex
	queueSize   int
	subscribers map[*Subscription]struct{}
}

type Subscription struct {
	hub        *Hub
	events     chan Event
	overflowed chan struct{}
	dropped    bool
	once       sync.Once
}

func New(queueSize int) *Hub {
	if queueSize < 1 {
		queueSize = 1
	}
	return &Hub{queueSize: queueSize, subscribers: make(map[*Subscription]struct{})}
}

func (hub *Hub) Subscribe() *Subscription {
	subscription := &Subscription{hub: hub, events: make(chan Event, hub.queueSize), overflowed: make(chan struct{}, 1)}
	hub.mu.Lock()
	hub.subscribers[subscription] = struct{}{}
	hub.mu.Unlock()
	return subscription
}

func (hub *Hub) Publish(event Event) {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	for subscription := range hub.subscribers {
		if subscription.dropped {
			continue
		}
		select {
		case subscription.events <- event:
		default:
			subscription.dropped = true
			subscription.overflowed <- struct{}{}
		}
	}
}

func (subscription *Subscription) Events() <-chan Event        { return subscription.events }
func (subscription *Subscription) Overflowed() <-chan struct{} { return subscription.overflowed }

func (subscription *Subscription) AcknowledgeOverflow() {
	subscription.hub.mu.Lock()
	defer subscription.hub.mu.Unlock()
	for {
		select {
		case <-subscription.events:
		default:
			subscription.dropped = false
			select {
			case <-subscription.overflowed:
			default:
			}
			return
		}
	}
}

func (subscription *Subscription) Close() {
	subscription.once.Do(func() {
		subscription.hub.mu.Lock()
		delete(subscription.hub.subscribers, subscription)
		subscription.hub.mu.Unlock()
	})
}
