package senddirectmessage

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"reflect"
	"strings"
	"testing"
	"time"
)

const (
	senderID        = "11111111-1111-4111-8111-111111111111"
	directMessageID = "22222222-2222-4222-8222-222222222222"
	clientMessageID = "33333333-3333-4333-8333-333333333333"
	replyID         = "55555555-5555-4555-8555-555555555555"
)

func TestSendPersistsIdempotentDirectMessage(t *testing.T) {
	store := &fakeStore{result: Result{ID: "44444444-4444-4444-8444-444444444444", DirectMessageID: directMessageID, AuthorID: senderID, ClientMessageID: clientMessageID, Body: "Привет", ReplyToID: replyID, Revision: 1, CreatedAt: time.Unix(1, 0)}}
	service := New(store)
	service.newID = func() (string, error) { return "44444444-4444-4444-8444-444444444444", nil }

	result, err := service.Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, ReplyToID: replyID, Body: "Привет"})

	if err != nil || store.request.ID != "44444444-4444-4444-8444-444444444444" || store.request.ReplyToID != replyID || !reflect.DeepEqual(result, store.result) {
		t.Fatalf("request=%#v result=%#v error=%v", store.request, result, err)
	}
}

func TestSendAcceptsAttachmentWithoutCaption(t *testing.T) {
	attachmentID := "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	store := &fakeStore{result: Result{ID: "44444444-4444-4444-8444-444444444444", Body: ""}}
	result, err := New(store).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, AttachmentIDs: []string{attachmentID}})
	if err != nil || !store.called || store.request.Body != "" || len(store.request.AttachmentIDs) != 1 || store.request.AttachmentIDs[0] != attachmentID || result.Body != "" {
		t.Fatalf("request=%#v result=%#v error=%v", store.request, result, err)
	}
}

func TestSendRejectsEmptyMessageWithoutAttachment(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

func TestSendRejectsEmptyOrOversizedMessageBeforePersistence(t *testing.T) {
	for _, body := range []string{"", strings.Repeat("я", 8001)} {
		store := &fakeStore{}
		_, err := New(store).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, Body: body})
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("body runes=%d error=%v called=%v", len([]rune(body)), err, store.called)
		}
	}
}

func TestSendRejectsMalformedReplyBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, ReplyToID: "not-a-uuid", Body: "Привет"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

func TestSendRejectsInvalidAttachmentListsBeforePersistence(t *testing.T) {
	valid := "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	tooMany := make([]string, 11)
	for index := range tooMany {
		tooMany[index] = uuid.NewString()
	}
	for _, ids := range [][]string{{"bad"}, {valid, valid}, tooMany} {
		store := &fakeStore{}
		_, err := New(store).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, Body: "Привет", AttachmentIDs: ids})
		if !errors.Is(err, ErrInvalidInput) || store.called {
			t.Fatalf("ids=%#v error=%v called=%v", ids, err, store.called)
		}
	}
}

func TestSendForwardsOrderedAttachmentIDs(t *testing.T) {
	ids := []string{"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}
	store := &fakeStore{}
	_, _ = New(store).Send(context.Background(), Input{ActorID: senderID, DirectMessageID: directMessageID, ClientMessageID: clientMessageID, Body: "Привет", AttachmentIDs: ids})
	if len(store.request.AttachmentIDs) != 2 || store.request.AttachmentIDs[1] != ids[1] {
		t.Fatalf("request=%#v", store.request)
	}
}

type fakeStore struct {
	called  bool
	request Request
	result  Result
}

func (store *fakeStore) Send(_ context.Context, request Request) (Result, error) {
	store.called, store.request = true, request
	return store.result, nil
}
