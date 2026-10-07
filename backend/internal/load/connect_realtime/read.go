package connect_realtime

import (
	"context"
	"encoding/json"
	"github.com/coder/websocket"
	"time"
)

func (s *Socket) read(ctx context.Context, conn *websocket.Conn, ready chan<- bool, resume bool) {
	sent, announced := false, false
	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			s.mu.Lock()
			if s.conn == conn {
				s.failure = true
			}
			s.mu.Unlock()
			if !sent {
				ready <- false
			}
			return
		}
		var event Event
		if json.Unmarshal(data, &event) != nil {
			continue
		}
		s.mu.Lock()
		if s.conn != conn {
			s.mu.Unlock()
			return
		}
		if event.Kind == "connection.ready" {
			announced = true
		}
		if event.Kind == "presence.snapshot" && announced && !sent {
			ready <- true
			sent = true
		}
		if event.Kind == "connection.resync_required" {
			s.resync = true
			s.results.Observe("resync", 200, 0)
		}
		if event.Kind == "message.created" {
			s.last = event.ID
			s.seen[event.Payload.MessageID] = time.Now()
			if resume && !sent {
				s.results.Observe("replay", 200, 0)
			}
			if len(s.seen) > 512 {
				for key := range s.seen {
					delete(s.seen, key)
					break
				}
			}
		}
		s.mu.Unlock()
		select {
		case s.wake <- struct{}{}:
		default:
		}
	}
}
