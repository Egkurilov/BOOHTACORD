package uploaddirectmessageattachment

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"

	authorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
	finalize "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

type Input struct {
	ActorID, DirectMessageID, OriginalName string
	Source                                 io.Reader
}
type Result = finalize.Result
type Authorizer interface {
	Authorize(context.Context, authorize.Input) error
}
type Stager interface {
	Stage(context.Context, io.Reader) (writeupload.Result, error)
}
type Finalizer interface {
	Finalize(context.Context, finalize.Input) (finalize.Result, error)
}
type Service struct {
	authorizer Authorizer
	stager     Stager
	finalizer  Finalizer
}

func New(authorizer Authorizer, stager Stager, finalizer Finalizer) Service {
	return Service{authorizer: authorizer, stager: stager, finalizer: finalizer}
}

func (service Service) Upload(ctx context.Context, input Input) (Result, error) {
	if err := service.authorizer.Authorize(ctx, authorize.Input{ActorID: input.ActorID, DirectMessageID: input.DirectMessageID}); err != nil {
		return Result{}, err
	}
	staged, err := service.stager.Stage(ctx, input.Source)
	if err != nil {
		return Result{}, err
	}
	result, err := service.finalizer.Finalize(ctx, finalize.Input{ActorID: input.ActorID, DirectMessageID: input.DirectMessageID, TempPath: staged.TempPath, OriginalName: input.OriginalName, SizeBytes: staged.SizeBytes})
	if err == nil {
		return result, nil
	}
	if removeErr := os.Remove(staged.TempPath); removeErr != nil && !errors.Is(removeErr, os.ErrNotExist) {
		return Result{}, fmt.Errorf("%w; remove staged direct message attachment: %v", err, removeErr)
	}
	return Result{}, err
}
