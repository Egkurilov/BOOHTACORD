package uploaddirectmessageattachment

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"

	authorize "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
	finalize "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment"
	writeupload "voice-platform/backend/internal/storage/write_upload"
)

func TestUploadAuthorizesBeforeStageAndFinalizesExactPair(t *testing.T) {
	auth, stage, done := &fakeAuthorizer{}, &fakeStager{}, &fakeFinalizer{}
	_, err := New(auth, stage, done).Upload(context.Background(), Input{ActorID: "actor", DirectMessageID: "pair", OriginalName: "a.txt", Source: strings.NewReader("abc")})
	if err != nil || !auth.called || !stage.called || done.input.DirectMessageID != "pair" || done.input.SizeBytes != 3 {
		t.Fatalf("error=%v auth=%#v stage=%#v done=%#v", err, auth, stage, done)
	}
	auth.err = authorize.ErrTargetUnavailable
	stage.called = false
	_, err = New(auth, stage, done).Upload(context.Background(), Input{})
	if !errors.Is(err, authorize.ErrTargetUnavailable) || stage.called {
		t.Fatalf("error=%v stage=%#v", err, stage)
	}
}

type fakeAuthorizer struct {
	called bool
	err    error
}

func (auth *fakeAuthorizer) Authorize(context.Context, authorize.Input) error {
	auth.called = true
	return auth.err
}

type fakeStager struct{ called bool }

func (stage *fakeStager) Stage(_ context.Context, source io.Reader) (writeupload.Result, error) {
	stage.called = true
	_, _ = io.Copy(io.Discard, source)
	return writeupload.Result{TempPath: "staged", SizeBytes: 3}, nil
}

type fakeFinalizer struct{ input finalize.Input }

func (done *fakeFinalizer) Finalize(_ context.Context, input finalize.Input) (finalize.Result, error) {
	done.input = input
	return finalize.Result{ID: "attachment"}, nil
}
