package senddirectmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMRepositoryRejectsEmptyMessageWithoutAttachmentInPostgres(t *testing.T) {
	f := newDMFixture(t)
	clientID := uuid.NewString()
	_, err := New(NewPoolDatabase(f.pool)).Send(context.Background(), send.Request{
		ID:    uuid.NewString(),
		Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: clientID},
	})
	if !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatalf("empty direct repository send error=%v", err)
	}
	assertDMMessageCount(t, f, clientID, 0)
}
