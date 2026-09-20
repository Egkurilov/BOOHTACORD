package listdirectmessagecandidates

import (
	"context"
	"errors"
	"fmt"
)

var ErrInvalidInput = errors.New("invalid direct message candidate input")

type Input struct {
	ActorID, After string
	Limit          int
}
type Request struct{ Input }
type Candidate struct{ ID, DisplayName string }
type Result struct {
	Candidates []Candidate
	NextAfter  string
}
type Store interface {
	List(context.Context, Request) ([]Candidate, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) List(context context.Context, input Input) (Result, error) {
	if !validUUID(input.ActorID) || (input.After != "" && !validUUID(input.After)) || input.Limit < 1 || input.Limit > 100 {
		return Result{}, ErrInvalidInput
	}
	candidates, err := service.store.List(context, Request{Input: input})
	if err != nil {
		return Result{}, fmt.Errorf("list direct message candidates: %w", err)
	}
	result := Result{Candidates: candidates}
	if len(result.Candidates) > input.Limit {
		result.NextAfter = result.Candidates[input.Limit-1].ID
		result.Candidates = result.Candidates[:input.Limit]
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
