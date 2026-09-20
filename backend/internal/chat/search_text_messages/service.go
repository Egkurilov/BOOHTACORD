package searchtextmessages

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"
)

var (
	ErrChannelUnavailable = errors.New("text channel unavailable")
	ErrInvalidInput       = errors.New("invalid text message search input")
)

type Input struct {
	ChannelID, Query, Before string
	Limit                    int
}
type Request struct{ Input }
type Message struct {
	ID, ChannelID, AuthorID, Body string
	CreatedAt                     time.Time
	EditedAt                      *time.Time
	Revision                      int
}
type Result struct {
	Messages   []Message
	NextCursor string
}
type Store interface {
	Search(context.Context, Request) ([]Message, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Search(context context.Context, input Input) (Result, error) {
	input.Query = strings.TrimSpace(input.Query)
	if !validUUID(input.ChannelID) || (input.Before != "" && !validUUID(input.Before)) || utf8.RuneCountInString(input.Query) < 1 || utf8.RuneCountInString(input.Query) > 256 || input.Limit < 1 || input.Limit > 100 {
		return Result{}, ErrInvalidInput
	}
	messages, err := service.store.Search(context, Request{Input: input})
	if errors.Is(err, ErrChannelUnavailable) {
		return Result{}, ErrChannelUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("search text messages: %w", err)
	}
	result := Result{Messages: messages}
	if len(result.Messages) > input.Limit {
		result.Messages = result.Messages[:input.Limit]
		result.NextCursor = result.Messages[len(result.Messages)-1].ID
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
