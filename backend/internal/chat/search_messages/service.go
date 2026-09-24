package searchmessages

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	KindChannel       = "CHANNEL"
	KindDirectMessage = "DIRECT_MESSAGE"
)

var (
	ErrInvalidInput            = errors.New("invalid message search input")
	ErrConversationUnavailable = errors.New("search conversation unavailable")
)

type Input struct {
	ActorID, ChannelID, DirectMessageID, Query, Before string
	Limit                                              int
}
type Request struct {
	ActorID, ChannelID, DirectMessageID, Query string
	Before                                     *Cursor
	Limit                                      int
}
type Message struct {
	ID, Kind, ChannelID, DirectMessageID, AuthorID, Body string
	CreatedAt                                            time.Time
	EditedAt                                             *time.Time
	Revision                                             int
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

func (service Service) Search(ctx context.Context, input Input) (Result, error) {
	input.Query = strings.TrimSpace(input.Query)
	if !validUUID(input.ActorID) || (input.ChannelID != "" && !validUUID(input.ChannelID)) ||
		(input.DirectMessageID != "" && !validUUID(input.DirectMessageID)) ||
		(input.ChannelID != "" && input.DirectMessageID != "") || utf8.RuneCountInString(input.Query) < 1 ||
		utf8.RuneCountInString(input.Query) > 256 || input.Limit < 1 || input.Limit > 100 {
		return Result{}, ErrInvalidInput
	}
	var before *Cursor
	if input.Before != "" {
		var err error
		before, err = decodeCursor(input.Before)
		if err != nil {
			return Result{}, ErrInvalidInput
		}
	}
	messages, err := service.store.Search(ctx, Request{ActorID: input.ActorID, ChannelID: input.ChannelID, DirectMessageID: input.DirectMessageID, Query: input.Query, Before: before, Limit: input.Limit})
	if errors.Is(err, ErrConversationUnavailable) {
		return Result{}, ErrConversationUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("search messages: %w", err)
	}
	result := Result{Messages: messages}
	if len(messages) > input.Limit {
		result.Messages = messages[:input.Limit]
		result.NextCursor, err = encodeCursor(result.Messages[len(result.Messages)-1])
		if err != nil {
			return Result{}, fmt.Errorf("encode message search cursor: %w", err)
		}
	}
	return result, nil
}
