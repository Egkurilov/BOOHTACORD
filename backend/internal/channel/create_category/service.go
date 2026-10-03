package createcategory

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"voice-platform/backend/internal/channel/category_name"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
)

var ErrInvalidInput = errors.New("invalid category creation input")

type Input struct {
	ActorID         string
	Name            string
	ClientRequestID string
}

type Request struct {
	ID              string
	ActorID         string
	Name            string
	ClientRequestID string
	IntentHash      string
}

type Result struct {
	ID       string
	Name     string
	Position int
	Revision int64
}

type Store interface {
	Create(context.Context, Request) (Result, error)
}

type Service struct {
	store Store
	newID func() (string, error)
}

func New(store Store) Service {
	return Service{store: store, newID: newCategoryID}
}

func (service Service) Create(context context.Context, input Input) (Result, error) {
	input.Name = strings.TrimSpace(input.Name)
	if input.ActorID == "" || categoryname.Validate(input.Name) != nil {
		return Result{}, ErrInvalidInput
	}
	intentHash := ""
	if input.ClientRequestID != "" {
		if topologycommand.ValidateClientRequestID(input.ClientRequestID) != nil {
			return Result{}, ErrInvalidInput
		}
		intentHash = topologycommand.Fingerprint(topologycommand.Intent{Operation: topologycommand.OperationCategoryCreate, Name: input.Name})
	}
	id, err := service.newID()
	if err != nil {
		return Result{}, fmt.Errorf("create category identifier: %w", err)
	}
	result, err := service.store.Create(context, Request{ID: id, ActorID: input.ActorID, Name: input.Name, ClientRequestID: input.ClientRequestID, IntentHash: intentHash})
	if err != nil {
		return Result{}, fmt.Errorf("persist category: %w", err)
	}
	return result, nil
}
