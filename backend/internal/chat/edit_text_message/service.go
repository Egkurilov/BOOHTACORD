package edittextmessage

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	validatementions "voice-platform/backend/internal/chat/validate_mentions"
)

var (
	ErrConflict     = errors.New("message edit conflict")
	ErrInvalidInput = errors.New("invalid text message edit input")
)

type Input struct {
	ActorID, ChannelID, MessageID, Body string
	ExpectedRevision                    int
	MentionUserIDs                      []string
}
type Request struct{ Input }
type Result struct {
	ID, ChannelID, AuthorID, ClientMessageID, Body, ReplyToID string
	Revision                                                  int
	CreatedAt, EditedAt                                       time.Time
	MentionUserIDs                                            []string
}
type Store interface {
	Edit(context.Context, Request) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) Edit(context context.Context, input Input) (Result, error) {
	if !validUUID(input.ActorID) || !validUUID(input.ChannelID) || !validUUID(input.MessageID) || input.ExpectedRevision < 1 || !validatementions.Valid(input.MentionUserIDs, input.ActorID) || !utf8.ValidString(input.Body) || utf8.RuneCountInString(input.Body) > 8000 || input.Body == "" || strings.ContainsRune(input.Body, '\x00') {
		return Result{}, ErrInvalidInput
	}
	result, err := service.store.Edit(context, Request{Input: input})
	if errors.Is(err, ErrConflict) {
		return Result{}, ErrConflict
	}
	if err != nil {
		return Result{}, fmt.Errorf("edit text message: %w", err)
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
