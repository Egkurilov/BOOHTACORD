package createtextmessage

import (
	"context"
	"errors"
	"testing"
)

const (
	attachmentTestMessageID = "f1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentTestChannelID = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentTestUserID    = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentTestClientID  = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestCreatePassesValidAttachmentIDsToStore(t *testing.T) {
	store := &fakeStore{}
	service := New(store)
	service.newID = func() (string, error) { return attachmentTestMessageID, nil }
	input := standardInput()
	input.AttachmentIDs = []string{"e1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"}
	if _, err := service.Create(context.Background(), input); err != nil || len(store.request.AttachmentIDs) != 1 {
		t.Fatalf("request = %#v, error = %v", store.request, err)
	}
}

func TestCreateAllowsAttachmentWithoutCaption(t *testing.T) {
	store := &fakeStore{}
	input := standardInput()
	input.Body = ""
	input.AttachmentIDs = []string{"e1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"}
	if _, err := New(store).Create(context.Background(), input); err != nil || !store.called || store.request.Body != "" || len(store.request.AttachmentIDs) != 1 {
		t.Fatalf("request = %#v, called = %v, error = %v", store.request, store.called, err)
	}
}

func TestCreateRejectsEmptyCaptionWithoutAttachments(t *testing.T) {
	store := &fakeStore{}
	input := standardInput()
	input.Body = ""
	_, err := New(store).Create(context.Background(), input)
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("called = %v, error = %v", store.called, err)
	}
}

func TestCreateRejectsInvalidAttachmentIDsBeforePersistence(t *testing.T) {
	valid := "e1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	for _, ids := range [][]string{{"invalid"}, {valid, valid}, elevenIDs(valid)} {
		store := &fakeStore{}
		input := standardInput()
		input.AttachmentIDs = ids
		_, err := New(store).Create(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("ids = %#v, called = %v, error = %v", ids, store.called, err)
		}
	}
}

func standardInput() Input {
	return Input{ActorID: attachmentTestUserID, ChannelID: attachmentTestChannelID, ClientMessageID: attachmentTestClientID, Body: "Привет"}
}

func elevenIDs(id string) []string {
	result := make([]string, 11)
	for index := range result {
		result[index] = id
	}
	return result
}
