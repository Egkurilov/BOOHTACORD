package stageupload

import (
	"context"
	"io"

	reserveuploadspace "voice-platform/backend/internal/storage/reserve_upload_space"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

type Service struct {
	manager *reserveuploadspace.Manager
	writer  writeupload.Writer
}

func New(manager *reserveuploadspace.Manager, writer writeupload.Writer) Service {
	return Service{manager: manager, writer: writer}
}

func (service Service) Stage(ctx context.Context, source io.Reader) (writeupload.Result, error) {
	reservation, err := service.manager.Reserve(ctx)
	if err != nil {
		return writeupload.Result{}, err
	}
	defer reservation.Release()
	return service.writer.WriteGuarded(ctx, source, service.manager.Confirm)
}
