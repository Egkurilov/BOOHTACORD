package senddirectmessagepostgres

import (
	"context"
	"errors"
	"sync"
	"testing"

	"github.com/google/uuid"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMAttachConcurrentDifferentSendsClaimOnlyOnce(t *testing.T) {
	f := newDMFixture(t)
	repository := New(NewPoolDatabase(f.pool))
	start := make(chan struct{})
	results := make([]send.Result, 2)
	outcomes := make([]error, 2)
	var wait sync.WaitGroup
	for i := range results {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			<-start
			results[i], outcomes[i] = repository.Send(context.Background(), send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "different", AttachmentIDs: []string{f.attachment}}})
		}(i)
	}
	close(start)
	wait.Wait()
	success, denied := 0, 0
	for i, err := range outcomes {
		if err == nil && results[i].ID != "" {
			success++
		} else if errors.Is(err, send.ErrDirectMessageUnavailable) {
			denied++
		} else {
			t.Fatalf("send %d result=%#v error=%v", i, results[i], err)
		}
	}
	if success != 1 || denied != 1 {
		t.Fatalf("success=%d denied=%d", success, denied)
	}
	var links, messages int
	if err := f.pool.QueryRow(context.Background(), `SELECT count(*) FROM direct_message_attachments WHERE attachment_id=$1`, f.attachment).Scan(&links); err != nil {
		t.Fatal(err)
	}
	if err := f.pool.QueryRow(context.Background(), `SELECT count(*) FROM direct_message_messages WHERE direct_message_id=$1`, f.pair).Scan(&messages); err != nil {
		t.Fatal(err)
	}
	if links != 1 || messages != 1 {
		t.Fatalf("links=%d messages=%d", links, messages)
	}
}
