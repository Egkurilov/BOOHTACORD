package createtextmessage

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"
	flowstage "voice-platform/backend/internal/observability/flow_stage"

	validatementions "voice-platform/backend/internal/chat/validate_mentions"
)

var (
	ErrChannelUnavailable = errors.New("text channel or reply unavailable")
	ErrInvalidInput       = errors.New("invalid text message input")
)

type Input struct {
	ActorID, ChannelID, ClientMessageID, Body, ReplyToID string
	AttachmentIDs                                        []string
	MentionUserIDs                                       []string
}
type Request struct {
	ID string
	Input
}
type Result struct {
	ID, ChannelID, AuthorID, ClientMessageID, Body, ReplyToID string
	Revision                                                  int
	CreatedAt                                                 time.Time
	MentionUserIDs                                            []string
}
type Store interface {
	Create(context.Context, Request) (Result, error)
}
type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service { return Service{store: store, newID: newMessageID} }
func (service Service) Create(context context.Context, input Input) (result Result, err error) {
	context, span := flowstage.Begin(context, "message.send.server", "authorize")
	defer func() {
		flowstage.End(span, err, flowstage.Reject(ErrInvalidInput, "invalid"), flowstage.Reject(ErrChannelUnavailable, "permission_denied"))
	}()
	if !validUUID(input.ActorID) || !validUUID(input.ChannelID) || !validUUID(input.ClientMessageID) || (input.ReplyToID != "" && !validUUID(input.ReplyToID)) || !validAttachments(input.AttachmentIDs) || !validatementions.Valid(input.MentionUserIDs, input.ActorID) || !utf8.ValidString(input.Body) || utf8.RuneCountInString(input.Body) > 8000 || (input.Body == "" && len(input.AttachmentIDs) == 0) || strings.ContainsRune(input.Body, '\x00') {
		return Result{}, ErrInvalidInput
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create message identifier: %w", err)
	}
	result, err = service.store.Create(context, Request{ID: id, Input: input})
	if errors.Is(err, ErrChannelUnavailable) {
		return Result{}, ErrChannelUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("persist text message: %w", err)
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
