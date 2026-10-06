package senddirectmessage

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	validatementions "voice-platform/backend/internal/chat/validate_mentions"
	flowstage "voice-platform/backend/internal/observability/flow_stage"
)

var (
	ErrDirectMessageUnavailable = errors.New("direct message unavailable")
	ErrInvalidInput             = errors.New("invalid direct message input")
)

type Input struct {
	ActorID, DirectMessageID, ClientMessageID, ReplyToID, Body string
	AttachmentIDs                                              []string
	MentionUserIDs                                             []string
}
type Request struct {
	ID string
	Input
}
type Result struct {
	ID, DirectMessageID, AuthorID, ClientMessageID, Body, ReplyToID string
	Revision                                                        int
	CreatedAt                                                       time.Time
	MentionUserIDs                                                  []string
}
type Store interface {
	Send(context.Context, Request) (Result, error)
}
type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service { return Service{store: store, newID: newDirectMessageMessageID} }

func (service Service) Send(context context.Context, input Input) (result Result, err error) {
	context, span := flowstage.Begin(context, "message.send.server", "authorize")
	defer func() {
		flowstage.End(span, err, flowstage.Reject(ErrInvalidInput, "invalid"), flowstage.Reject(ErrDirectMessageUnavailable, "permission_denied"))
	}()
	if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || !validUUID(input.ClientMessageID) || (input.ReplyToID != "" && !validUUID(input.ReplyToID)) || !validAttachments(input.AttachmentIDs) || !validatementions.Valid(input.MentionUserIDs, input.ActorID) || !utf8.ValidString(input.Body) || utf8.RuneCountInString(input.Body) > 8000 || (input.Body == "" && len(input.AttachmentIDs) == 0) || strings.ContainsRune(input.Body, '\x00') {
		return Result{}, ErrInvalidInput
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create direct message message identifier: %w", err)
	}
	result, err = service.store.Send(context, Request{ID: id, Input: input})
	if errors.Is(err, ErrDirectMessageUnavailable) {
		return Result{}, ErrDirectMessageUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("persist direct message: %w", err)
	}
	return result, nil
}

func validUUID(value string) bool {
	if len(value) != 36 {
		return false
	}
	for index, character := range value {
		if index == 8 || index == 13 || index == 18 || index == 23 {
			if character != '-' {
				return false
			}
			continue
		}
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f') || (character >= 'A' && character <= 'F')) {
			return false
		}
	}
	return true
}
