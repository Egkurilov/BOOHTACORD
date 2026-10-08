package listconnectedparticipants

import (
	"context"
	"testing"

	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
)

func TestListReportsSnapshotValidationStageWithoutRawDetails(t *testing.T) {
	observer := &snapshotObserver{}
	presence, err := snapshotlivekitpresence.New(snapshotlivekitpresence.Config{URL: "http://localhost", APIKey: "key", APISecret: "secret"})
	if err != nil {
		t.Fatal(err)
	}
	service := New(&repositoryStub{channels: []Channel{{ID: "invalid-room-id"}}}, presence, observer)
	_, err = service.List(context.Background(), actorID)
	if err == nil || len(observer.failures) != 1 || observer.failures[0] != "presence_validation" {
		t.Fatalf("error=%v failure stages=%v", err, observer.failures)
	}
}
