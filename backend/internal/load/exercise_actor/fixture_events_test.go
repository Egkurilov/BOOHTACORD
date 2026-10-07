package exercise_actor

import (
	"context"
	"encoding/json"
	"github.com/coder/websocket"
	"github.com/google/uuid"
	"net/http"
	"time"
)

func (f *fixture) ws(w http.ResponseWriter, r *http.Request) {
	conn, err := websocket.Accept(w, r, nil)
	if err != nil {
		return
	}
	defer conn.CloseNow()
	f.mu.Lock()
	ctx, cancel := context.WithTimeout(r.Context(), time.Second)
	defer cancel()
	send := func(value any) { data, _ := json.Marshal(value); conn.Write(ctx, websocket.MessageText, data) }
	send(map[string]any{"event_id": uuid.NewString(), "kind": "connection.ready", "payload": map[string]any{}})
	if r.URL.Query().Get("after") != "" {
		if f.forceResync {
			send(map[string]any{"event_id": uuid.NewString(), "kind": "connection.resync_required", "payload": map[string]string{"reason": "server_restart"}})
		} else {
			for _, event := range f.events {
				send(event)
			}
		}
	}
	send(map[string]any{"event_id": uuid.NewString(), "kind": "presence.snapshot", "payload": map[string]any{"online_user_ids": []string{f.manifest.Accounts[0].ID}}})
	f.sockets[conn] = true
	f.mu.Unlock()
	for {
		if _, _, err := conn.Read(r.Context()); err != nil {
			break
		}
	}
	f.mu.Lock()
	delete(f.sockets, conn)
	f.mu.Unlock()
}
func (f *fixture) message(w http.ResponseWriter, r *http.Request) {
	var input map[string]any
	if json.NewDecoder(r.Body).Decode(&input) != nil {
		w.WriteHeader(400)
		return
	}
	id := uuid.NewString()
	event := map[string]any{"event_id": uuid.NewString(), "kind": "message.created", "payload": map[string]any{"message_id": id}}
	f.mu.Lock()
	f.events = append(f.events, event)
	data, _ := json.Marshal(event)
	for conn := range f.sockets {
		ctx, cancel := context.WithTimeout(r.Context(), time.Second)
		conn.Write(ctx, websocket.MessageText, data)
		cancel()
	}
	f.mu.Unlock()
	w.WriteHeader(201)
	json.NewEncoder(w).Encode(map[string]any{"id": id})
}
