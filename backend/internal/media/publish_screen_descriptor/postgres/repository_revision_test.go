package publishscreendescriptorpostgres

import (
	"context"
	"errors"
	"testing"

	publishdescriptor "voice-platform/backend/internal/media/publish_screen_descriptor"
)

func TestApplyRejectsStaleRevision(t *testing.T) {
	database := &fakeDatabase{account: testAccount, channel: testChannel, lease: testLease, digest: make([]byte, 32)}
	database.digest[0] = 5
	publisher := &fakePublisher{}
	repository := New(database, publisher)
	principal := publishdescriptor.Principal{AccountID: testAccount}
	principal.SessionDigest[0] = 5
	value := testDescriptor()
	value.Scope.OperationRevision = 2
	if err := repository.Apply(context.Background(), principal, testLease, "https://voice.example.test", value); err != nil {
		t.Fatal(err)
	}
	value.Scope.OperationRevision = 1
	if err := repository.Apply(context.Background(), principal, testLease, "https://voice.example.test", value); !errors.Is(err, publishdescriptor.ErrStale) {
		t.Fatalf("stale update = %v", err)
	}
	if publisher.calls != 1 {
		t.Fatal("stale update reached LiveKit")
	}
}

func TestApplyRetriesEqualRevisionIdempotentlyAndRejectsChangedPayload(t *testing.T) {
	database := &fakeDatabase{account: testAccount, channel: testChannel, lease: testLease, digest: make([]byte, 32)}
	database.digest[0] = 5
	publisher := &fakePublisher{}
	repository := New(database, publisher)
	principal := publishdescriptor.Principal{AccountID: testAccount}
	principal.SessionDigest[0] = 5
	value := testDescriptor()
	for attempt := 0; attempt < 2; attempt++ {
		if err := repository.Apply(context.Background(), principal, testLease, "https://voice.example.test", value); err != nil {
			t.Fatal(err)
		}
	}
	if publisher.calls != 2 || database.revision != 1 {
		t.Fatalf("retry state: calls=%d revision=%d", publisher.calls, database.revision)
	}
	value.ReasonCodes = []string{"platform-constraint"}
	if err := repository.Apply(context.Background(), principal, testLease, "https://voice.example.test", value); !errors.Is(err, publishdescriptor.ErrConflict) {
		t.Fatalf("changed duplicate revision = %v", err)
	}
	if publisher.calls != 2 {
		t.Fatal("conflicting retry reached LiveKit")
	}
}
