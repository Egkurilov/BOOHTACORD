package senddirectmessagepostgres

import (
	"context"
	"sync"
	"testing"

	"github.com/google/uuid"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMAttachConcurrentIdempotencyWithPostgres(t *testing.T) {
	f := newDMFixture(t)
	repository := New(NewPoolDatabase(f.pool))
	clientID := uuid.NewString()
	start := make(chan struct{})
	results := make([]send.Result, 2)
	errors := make([]error, 2)
	var wait sync.WaitGroup
	for i := range results {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			<-start
			results[i], errors[i] = repository.Send(context.Background(), send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: clientID, AttachmentIDs: []string{f.attachment}}})
		}(i)
	}
	close(start)
	wait.Wait()
	for i, err := range errors {
		if err != nil {
			t.Fatalf("send %d: %v", i, err)
		}
	}
	if results[0].ID == "" || results[0].ID != results[1].ID || results[0].Body != "" || results[1].Body != "" {
		t.Fatalf("results=%#v", results)
	}
	assertDMMessageCount(t, f, clientID, 1)
	var links int
	if err := f.pool.QueryRow(context.Background(), `SELECT count(*) FROM direct_message_attachments WHERE message_id=$1`, results[0].ID).Scan(&links); err != nil || links != 1 {
		t.Fatalf("links=%d error=%v", links, err)
	}
}
