package deleteemptycategory

import (
	"context"
	"errors"
	topologycommand "voice-platform/backend/internal/channel/topology_command"
)

var (
	ErrInvalidInput     = errors.New("invalid empty category deletion input")
	ErrRevisionConflict = errors.New("category deletion conflict")
)

type Input struct {
	ActorID, CategoryID string
	ExpectedRevision    int64
	ConfirmDelete       bool
	ClientRequestID     string
	IntentHash          string
}
type Result struct {
	ID       string
	Revision int64
}
type Store interface {
	Delete(context.Context, Input) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) Delete(ctx context.Context, input Input) (Result, error) {
	if input.ActorID == "" || input.CategoryID == "" || input.ExpectedRevision < 1 {
		return Result{}, ErrInvalidInput
	}
	if input.ClientRequestID != "" {
		if !input.ConfirmDelete || topologycommand.ValidateClientRequestID(input.ClientRequestID) != nil {
			return Result{}, ErrInvalidInput
		}
		input.IntentHash = topologycommand.Fingerprint(topologycommand.Intent{Operation: topologycommand.OperationCategoryDelete, ResourceID: input.CategoryID, Confirmation: true})
	}
	return service.store.Delete(ctx, input)
}
