package connect_realtime

import (
	"context"
	"encoding/json"
	"github.com/coder/websocket"
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
		if !s.apply(conn, event, resume && !sent) {
			return
		}
		if event.Kind == "connection.ready" {
			announced = true
		}
		if event.Kind == "presence.snapshot" && announced && !sent {
			ready <- true
			sent = true
		}
	}
}
