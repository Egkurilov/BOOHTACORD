package listdirectmessagehistory

import (
	"context"
	"errors"
	"fmt"
	"time"
)

var (
	ErrDirectMessageUnavailable = errors.New("direct message unavailable")
	ErrInvalidInput             = errors.New("invalid direct message history input")
)

type Input struct {
	ActorID, DirectMessageID, Before string
	Limit                            int
}
type Request struct{ Input }
type ReplyPreview struct {
	ID, AuthorID, Body string
	Deleted            bool
}
type Attachment struct {
	ID           string `json:"id"`
	OriginalName string `json:"original_name"`
	ByteSize     int64  `json:"byte_size"`
}
type Message struct {
	ID, DirectMessageID, AuthorID, ClientMessageID, Body, ReplyToID string
	CreatedAt                                                       time.Time
	EditedAt                                                        *time.Time
	Revision                                                        int
	Deleted                                                         bool
	ReplyPreview                                                    *ReplyPreview
	Attachments                                                     []Attachment
	MentionUserIDs                                                  []string
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
	if !validUUID(input.ActorID) || !validUUID(input.DirectMessageID) || (input.Before != "" && !validUUID(input.Before)) || input.Limit < 1 || input.Limit > 100 {
		return Result{}, ErrInvalidInput
	}
	messages, err := service.store.List(context, Request{Input: input})
	if errors.Is(err, ErrDirectMessageUnavailable) {
		return Result{}, ErrDirectMessageUnavailable
	}
	if err != nil {
		return Result{}, fmt.Errorf("list direct message history: %w", err)
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
