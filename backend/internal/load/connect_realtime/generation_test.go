package connect_realtime

import (
	"github.com/coder/websocket"
	"testing"
	"voice-platform/backend/internal/load/record_results"
)

func TestStaleGenerationCannotChangeCurrentState(t *testing.T) {
	r := record_results.New()
	s := New(r)
	old, current := &websocket.Conn{}, &websocket.Conn{}
	s.conn = current
	s.last = "current-event"
	for _, kind := range []string{"connection.ready", "connection.resync_required", "presence.snapshot", "message.created"} {
		event := Event{ID: "stale-event", Kind: kind}
		event.Payload.MessageID = "stale-message"
		if s.apply(old, event, true) {
			t.Fatal("stale decoded event accepted")
		}
	}
	if s.resync || s.last != "current-event" || len(s.seen) != 0 || len(s.wake) != 0 || len(r.Snapshot()) != 0 {
		t.Fatal("stale generation altered state")
	}
	event := Event{ID: "next", Kind: "message.created"}
	event.Payload.MessageID = "valid"
	if !s.apply(current, event, true) || s.last != "next" || len(s.seen) != 1 {
		t.Fatal("current generation ignored")
	}
}
