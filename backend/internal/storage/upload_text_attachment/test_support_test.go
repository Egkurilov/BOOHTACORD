package uploadtextattachment

import (
	"context"
	"io"

	authorize "voice-platform/backend/internal/storage/authorize_text_attachment"
	finalize "voice-platform/backend/internal/storage/finalize_staged_text_attachment"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

type fakeAuthorizer struct {
	called bool
	err    error
}

func (authorizer *fakeAuthorizer) Authorize(_ context.Context, _ authorize.Input) error {
	authorizer.called = true
	return authorizer.err
}

type fakeStager struct {
	called bool
	result writeupload.Result
	err    error
}

func (stager *fakeStager) Stage(_ context.Context, _ io.Reader) (writeupload.Result, error) {
	stager.called = true
	return stager.result, stager.err
}

type fakeFinalizer struct {
	called bool
	input  finalize.Input
	result finalize.Result
	err    error
}

func (finalizer *fakeFinalizer) Finalize(_ context.Context, input finalize.Input) (finalize.Result, error) {
	finalizer.called, finalizer.input = true, input
	return finalizer.result, finalizer.err
}
