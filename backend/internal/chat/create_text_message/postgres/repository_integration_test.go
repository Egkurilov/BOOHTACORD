package createtextmessagepostgres

import (
	"context"
	"sync"
	"testing"

	"github.com/google/uuid"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
)

func TestRepositoryIdempotencyWithPostgresMigrations(t *testing.T) {
	fixture := newTextMessageFixture(t)
	context := context.Background()
	repository := New(NewPoolDatabase(fixture.pool))
	clientID := uuid.NewString()
	first, err := repository.Create(context, createtextmessage.Request{ID: uuid.NewString(), Input: createtextmessage.Input{
		ActorID: fixture.authorID, ChannelID: fixture.channelID, ClientMessageID: clientID, Body: "first body",
	}})
	if err != nil {
		t.Fatal("initial send:", err)
	}
	retry, err := repository.Create(context, createtextmessage.Request{ID: uuid.NewString(), Input: createtextmessage.Input{
		ActorID: fixture.authorID, ChannelID: fixture.channelID, ClientMessageID: clientID, Body: "retry body",
	}})
	if err != nil {
		t.Fatal("serial retry:", err)
	}
	if retry.ID != first.ID || retry.Body != first.Body {
		t.Fatalf("serial retry changed message: first=%#v retry=%#v", first, retry)
	}
	assertMessageCount(t, fixture, clientID, 1)

	concurrentClientID := uuid.NewString()
	start := make(chan struct{})
	var wait sync.WaitGroup
	results := make([]createtextmessage.Result, 2)
	errors := make([]error, 2)
	for index := range results {
		wait.Add(1)
		go func(index int) {
			defer wait.Done()
			<-start
			results[index], errors[index] = repository.Create(context, createtextmessage.Request{ID: uuid.NewString(), Input: createtextmessage.Input{
				ActorID: fixture.authorID, ChannelID: fixture.channelID, ClientMessageID: concurrentClientID,
				Body: "concurrent send", AttachmentIDs: []string{fixture.attachmentID},
			}})
		}(index)
	}
	close(start)
	wait.Wait()
	for index, err := range errors {
		if err != nil {
			t.Fatalf("concurrent send %d: %v", index, err)
		}
	}
	if results[0].ID == "" || results[0].ID != results[1].ID {
		t.Fatalf("concurrent sends returned different messages: %#v", results)
	}
	assertMessageCount(t, fixture, concurrentClientID, 1)
	var links int
	if err := fixture.pool.QueryRow(context, "SELECT count(*) FROM message_attachments WHERE message_id = $1", results[0].ID).Scan(&links); err != nil {
		t.Fatal("count attachment links:", err)
	}
	if links != 1 {
		t.Fatalf("attachment links = %d, want 1", links)
	}
}

func assertMessageCount(t *testing.T, fixture textMessageFixture, clientID string, want int) {
	t.Helper()
	var count int
	err := fixture.pool.QueryRow(context.Background(),
		"SELECT count(*) FROM messages WHERE author_id = $1 AND channel_id = $2 AND client_message_id = $3",
		fixture.authorID, fixture.channelID, clientID).Scan(&count)
	if err != nil || count != want {
		t.Fatalf("message count = %d, want %d, error = %v", count, want, err)
	}
}
