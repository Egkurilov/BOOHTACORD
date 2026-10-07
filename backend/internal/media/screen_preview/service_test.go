package screenpreview

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"testing"

	"github.com/google/uuid"
)

type testAuthority struct {
	owner, viewer bool
	channel       string
}

func (authority testAuthority) AuthorizeUploader(context.Context, Principal, string) (string, error) {
	if !authority.owner {
		return "", ErrDenied
	}
	return authority.channel, nil
}
func (authority testAuthority) AuthorizeViewer(context.Context, Principal, string) (string, error) {
	if !authority.viewer {
		return "", ErrDenied
	}
	return authority.channel, nil
}

type testPublication struct {
	track string
	err   error
	calls int
}

func (publication *testPublication) CurrentTrack(context.Context, string, string) (string, error) {
	publication.calls++
	return publication.track, publication.err
}

func TestPreviewRequiresCurrentPublicationAndSeparateViewerPermission(t *testing.T) {
	authority := testAuthority{owner: true, viewer: false, channel: uuid.NewString()}
	publication := &testPublication{track: "live-track-a"}
	cache := &testStore{}

	service, err := New(authority, publication, cache)
	if err != nil {
		t.Fatal(err)
	}
	lease := uuid.NewString()
	generation, err := service.Begin(context.Background(), Principal{AccountID: uuid.NewString()}, lease)
	if err != nil || generation.SchemaVersion != 1 {
		t.Fatalf("generation = %+v, err = %v", generation, err)
	}
	frame := image.NewRGBA(image.Rect(0, 0, 2, 2))
	frame.Set(0, 0, color.RGBA{R: 255, A: 255})
	var encoded bytes.Buffer
	if err := jpeg.Encode(&encoded, frame, &jpeg.Options{Quality: 30}); err != nil {
		t.Fatal(err)
	}
	if err := service.Upload(context.Background(), Principal{AccountID: uuid.NewString()}, lease, generation.GenerationID, 1, encoded.Bytes()); err != nil {
		t.Fatal(err)
	}
	if _, err := service.Read(context.Background(), Principal{}, lease, generation.GenerationID, 0); !errors.Is(err, ErrDenied) {
		t.Fatalf("unauthorized viewer error = %v", err)
	}
	service.authority = testAuthority{viewer: true, channel: authority.channel}
	preview, err := service.Read(context.Background(), Principal{}, lease, generation.GenerationID, 0)
	if err != nil || preview.Revision != 1 || !bytes.Equal(preview.JPEG, encoded.Bytes()) {
		t.Fatalf("preview = %+v, err = %v", preview, err)
	}
	if _, err := service.Read(context.Background(), Principal{}, lease, generation.GenerationID, 1); !errors.Is(err, ErrNoUpdate) {
		t.Fatalf("unchanged revision error = %v", err)
	}
	publication.track = "live-track-b"
	if _, err := service.Read(context.Background(), Principal{}, lease, generation.GenerationID, 0); !errors.Is(err, ErrNotFound) {
		t.Fatalf("old publication generation error = %v", err)
	}
}

func TestDeniedUploaderAndUnavailablePublicationNeverCreateGeneration(t *testing.T) {
	cache := &testStore{}

	publication := &testPublication{track: "track"}
	service, err := New(testAuthority{channel: uuid.NewString()}, publication, cache)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.Begin(context.Background(), Principal{}, uuid.NewString()); !errors.Is(err, ErrDenied) {
		t.Fatalf("denied begin = %v", err)
	}
	if publication.calls != 0 {
		t.Fatal("denied uploader reached LiveKit")
	}
	service.authority = testAuthority{owner: true, channel: uuid.NewString()}
	publication.err = errors.New("RoomService offline")
	if _, err := service.Begin(context.Background(), Principal{}, uuid.NewString()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("unavailable publication = %v", err)
	}
}
