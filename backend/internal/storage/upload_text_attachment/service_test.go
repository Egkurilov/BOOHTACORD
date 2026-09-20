package uploadtextattachment

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"

	writeupload "voice-platform/backend/internal/storage/write_upload"
)

const (
	uploadActorID   = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	uploadChannelID = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestUploadAuthorizesStagesAndFinalizesMeasuredFile(t *testing.T) {
	authorizer, stager, finalizer := &fakeAuthorizer{}, &fakeStager{result: writeupload.Result{TempPath: "stage/file.part", SizeBytes: 5}}, &fakeFinalizer{}
	result, err := New(authorizer, stager, finalizer).Upload(context.Background(), Input{ActorID: uploadActorID, ChannelID: uploadChannelID, OriginalName: "image.png", Source: strings.NewReader("bytes")})
	if err != nil || !authorizer.called || !stager.called || !finalizer.called || finalizer.input.TempPath != "stage/file.part" || finalizer.input.SizeBytes != 5 || result.ID != finalizer.result.ID {
		t.Fatalf("result = %#v, authorizer = %#v, stager = %#v, finalizer = %#v, error = %v", result, authorizer, stager, finalizer, err)
	}
}

func TestUploadDoesNotStageAfterTargetDenial(t *testing.T) {
	authorizer, stager := &fakeAuthorizer{err: ErrTargetUnavailable}, &fakeStager{}
	_, err := New(authorizer, stager, &fakeFinalizer{}).Upload(context.Background(), validInput())
	if !errors.Is(err, ErrTargetUnavailable) || !authorizer.called || stager.called {
		t.Fatalf("authorizer = %#v, stager = %#v, error = %v", authorizer, stager, err)
	}
}

func TestUploadRemovesStagedFileAfterFinalizationFailure(t *testing.T) {
	path := t.TempDir() + "/upload.part"
	if err := os.WriteFile(path, []byte("bytes"), 0o600); err != nil {
		t.Fatal(err)
	}
	_, err := New(&fakeAuthorizer{}, &fakeStager{result: writeupload.Result{TempPath: path, SizeBytes: 5}}, &fakeFinalizer{err: errors.New("database unavailable")}).Upload(context.Background(), validInput())
	if err == nil {
		t.Fatal("expected finalization error")
	}
	if _, statErr := os.Stat(path); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("temporary path error = %v", statErr)
	}
}

func validInput() Input {
	return Input{ActorID: uploadActorID, ChannelID: uploadChannelID, OriginalName: "image.png", Source: strings.NewReader("bytes")}
}
