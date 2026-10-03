package createchannel

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"voice-platform/backend/internal/channel/category_name"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
)

var (
	ErrInvalidInput     = errors.New("invalid channel creation input")
	ErrCategoryNotFound = errors.New("category not found")
)

type Kind string

const (
	KindText  Kind = "TEXT"
	KindVoice Kind = "VOICE"
)

type Input struct {
	ActorID         string
	CategoryID      string
	Name            string
	Kind            Kind
	ClientRequestID string
}

type Request struct {
	ID string
	Input
	IntentHash string
}

type Result struct {
	ID         string
	CategoryID string
	Name       string
	Kind       Kind
	Position   int
	Revision   int64
}

type Store interface {
	Create(context.Context, Request) (Result, error)
}

type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service {
	return Service{store: store, newID: newChannelID}
}

func (service Service) Create(context context.Context, input Input) (Result, error) {
	input.Name = strings.TrimSpace(input.Name)
	if input.ActorID == "" || input.CategoryID == "" || categoryname.Validate(input.Name) != nil || (input.Kind != KindText && input.Kind != KindVoice) {
		return Result{}, ErrInvalidInput
	}
	intentHash := ""
	if input.ClientRequestID != "" {
		if topologycommand.ValidateClientRequestID(input.ClientRequestID) != nil {
			return Result{}, ErrInvalidInput
		}
		operation := topologycommand.OperationTextCreate
		if input.Kind == KindVoice {
			operation = topologycommand.OperationVoiceCreate
		}
		intentHash = topologycommand.Fingerprint(topologycommand.Intent{Operation: operation, ParentID: input.CategoryID, Kind: string(input.Kind), Name: input.Name})
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create channel identifier: %w", err)
	}
	result, err := service.store.Create(context, Request{ID: id, Input: input, IntentHash: intentHash})
	if errors.Is(err, ErrCategoryNotFound) {
		return Result{}, ErrCategoryNotFound
	}
	if err != nil {
		return Result{}, fmt.Errorf("persist channel: %w", err)
	}
	return result, nil
}
