package screenpreview

import (
	"context"
	"github.com/google/uuid"
	"testing"
)

type testHints struct {
	updates, invalidations int
	lease, generation      string
	revision               uint64
}

func (hints *testHints) Updated(_ context.Context, lease, generation string, revision uint64) {
	hints.updates++
	hints.lease, hints.generation, hints.revision = lease, generation, revision
}
func (hints *testHints) Invalidated(_ context.Context, lease, generation string) {
	hints.invalidations++
	hints.lease, hints.generation = lease, generation
}

func TestUploadAndInvalidationPublishMetadataHints(t *testing.T) {
	hints := &testHints{}
	lease := uuid.NewString()
	service, err := New(testAuthority{owner: true, channel: uuid.NewString()}, &testPublication{track: "track"}, &testStore{}, hints)
	if err != nil {
		t.Fatal(err)
	}
	generation, err := service.Begin(context.Background(), Principal{}, lease)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.Upload(context.Background(), Principal{}, lease, generation.GenerationID, 1, testJPEG(t, 32, 32)); err != nil {
		t.Fatal(err)
	}
	if hints.updates != 1 || hints.lease != lease || hints.generation != generation.GenerationID || hints.revision != 1 {
		t.Fatalf("upload hint = %+v", hints)
	}
	if err := service.Invalidate(context.Background(), Principal{}, lease, generation.GenerationID); err != nil {
		t.Fatal(err)
	}
	if hints.invalidations != 1 || hints.generation != generation.GenerationID {
		t.Fatalf("invalidation hint = %+v", hints)
	}
}
