package uploadtextattachment

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"

	authorize "voice-platform/backend/internal/storage/authorize_text_attachment"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

var ErrTargetUnavailable = authorize.ErrTargetUnavailable

type Result = finalize.Result

type Input struct {
	ActorID, ChannelID, OriginalName string
	Source                           io.Reader
}
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

func (service Service) Upload(ctx context.Context, input Input) (finalize.Result, error) {
	if err := service.authorizer.Authorize(ctx, authorize.Input{ActorID: input.ActorID, ChannelID: input.ChannelID}); err != nil {
		return finalize.Result{}, err
	}
	staged, err := service.stager.Stage(ctx, input.Source)
	if err != nil {
		return finalize.Result{}, err
	}
	result, err := service.finalizer.Finalize(ctx, finalize.Input{ActorID: input.ActorID, ChannelID: input.ChannelID, TempPath: staged.TempPath, OriginalName: input.OriginalName, SizeBytes: staged.SizeBytes})
	if err == nil {
		return result, nil
	}
	if removeErr := os.Remove(staged.TempPath); removeErr != nil && !errors.Is(removeErr, os.ErrNotExist) {
		return finalize.Result{}, fmt.Errorf("%w; remove staged attachment: %v", err, removeErr)
	}
	return finalize.Result{}, err
}
