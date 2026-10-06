package eventhub

import (
	"context"
	"time"
	cause "voice-platform/backend/internal/observability/causal_reference"
)

type TelemetryEnvelope struct {
	Reference string `json:"reference"`
	TraceID   string `json:"trace_id"`
	SpanID    string `json:"span_id"`
}

func (hub *Hub) SetTelemetryKey(key string) {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	hub.telemetryKey = key
}
func (hub *Hub) Correlate(ctx context.Context, accountID string, event Event) Event {
	event.Telemetry = nil
	if hub == nil || !event.Cause.Valid() {
		return event
	}
	allowed, err := hub.Authorize(ctx, accountID, event)
	if err != nil || !allowed {
		return event
	}
	hub.mu.Lock()
	key := hub.telemetryKey
	hub.mu.Unlock()
	reference := cause.Sign(key, accountID, event.Cause, time.Now())
	if reference != "" {
		event.Telemetry = &TelemetryEnvelope{reference, event.Cause.TraceID, event.Cause.SpanID}
	}
	return event
}
func (s *Subscription) Supports(name string) bool {
	if s == nil {
		return false
	}
	_, ok := s.capabilities[name]
	return ok
}
