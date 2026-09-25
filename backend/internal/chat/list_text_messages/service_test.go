package listtextmessages

import (
	"context"
	"errors"
	"testing"
)

const (
	channelID    = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestListPreservesSafeAttachmentMetadataThroughPagination(t *testing.T) {
	store := &fakeStore{messages: []Message{{ID: "message-1", Attachments: []Attachment{{ID: attachmentID, OriginalName: "notes.svg", SizeBytes: 10}}}}}
	result, err := New(store).List(context.Background(), Input{ChannelID: channelID, Limit: 1})
	if err != nil || len(result.Messages) != 1 || len(result.Messages[0].Attachments) != 1 || result.Messages[0].Attachments[0].ID != attachmentID || result.Messages[0].Attachments[0].OriginalName != "notes.svg" || result.Messages[0].Attachments[0].SizeBytes != 10 {
		t.Fatalf("result = %#v, error = %v", result, err)
	}
}

func TestListTrimsLookaheadAndReturnsCursor(t *testing.T) {
	store := &fakeStore{messages: []Message{{ID: "message-3"}, {ID: "message-2"}, {ID: "message-1"}}}
	result, err := New(store).List(context.Background(), Input{ChannelID: channelID, Limit: 2})
	if err != nil || len(result.Messages) != 2 || result.NextCursor != "message-2" || store.request.Limit != 2 {
		t.Fatalf("result = %#v, request = %#v, error = %v", result, store.request, err)
	}
}

func TestListRejectsInvalidCursorAndLimitBeforePersistence(t *testing.T) {
	for _, input := range []Input{{ChannelID: channelID, Before: "nope", Limit: 10}, {ChannelID: channelID, At: "nope", Limit: 10}, {ChannelID: channelID, Before: attachmentID, At: attachmentID, Limit: 10}, {ChannelID: channelID, Limit: 101}} {
		store := &fakeStore{}
		_, err := New(store).List(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("input = %#v, error = %v", input, err)
		}
	}
}

func TestListForwardsAddressedContextAnchor(t *testing.T) {
	store := &fakeStore{messages: []Message{{ID: attachmentID}}}
	result, err := New(store).List(context.Background(), Input{ChannelID: channelID, At: attachmentID, Limit: 20})
	if err != nil || store.request.At != attachmentID || store.request.Before != "" || len(result.Messages) != 1 {
		t.Fatalf("result = %#v, request = %#v, error = %v", result, store.request, err)
	}
}

type fakeStore struct {
	called   bool
	request  Request
	messages []Message
}

func (store *fakeStore) List(_ context.Context, request Request) ([]Message, error) {
	store.called, store.request = true, request
	return store.messages, nil
}
