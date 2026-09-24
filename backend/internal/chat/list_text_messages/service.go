package listtextmessages

import (
	"context"
	"errors"
	"fmt"
	"time"
)

var (
	ErrChannelUnavailable = errors.New("text channel unavailable")
	ErrInvalidInput       = errors.New("invalid message page input")
)

type Input struct {
	ChannelID, Before string
	Limit             int
}
type Request struct{ Input }

type Attachment struct {
	ID           string `json:"id"`
	OriginalName string `json:"original_name"`
	SizeBytes    int64  `json:"byte_size"`
}

type Message struct {
	ID, ChannelID, AuthorID, ClientMessageID, Body, ReplyToID string
	CreatedAt                                                 time.Time
	EditedAt                                                  *time.Time
	Revision                                                  int
	Deleted                                                   bool
	Attachments                                               []Attachment
	MentionUserIDs                                            []string
}
type Result struct {
	Messages   []Message
	NextCursor string
}
type Store interface {
	List(context.Context, Request) ([]Message, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) List(context context.Context, input Input) (Result, error) {
	if !validUUID(input.ChannelID) || (input.Before != "" && !validUUID(input.Before)) || input.Limit < 1 || input.Limit > 100 {
		return Result{}, ErrInvalidInput
	}
	messages, err := service.store.List(context, Request{Input: input})
	if errors.Is(err, ErrChannelUnavailable) {
		return Result{}, ErrChannelUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("list text messages: %w", err)
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
