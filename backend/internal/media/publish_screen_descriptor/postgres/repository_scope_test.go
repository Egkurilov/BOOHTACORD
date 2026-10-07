package publishscreendescriptorpostgres

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	publishdescriptor "voice-platform/backend/internal/media/publish_screen_descriptor"
)

func TestApplyUsesLeaseOwnedScopeAndRejectsCrossAccount(t *testing.T) {
	database := &fakeDatabase{account: testAccount, channel: testChannel, lease: testLease, digest: make([]byte, 32)}
	database.digest[0] = 5
	publisher := &fakePublisher{}
	repository := New(database, publisher)
	principal := publishdescriptor.Principal{AccountID: testAccount}
	principal.SessionDigest[0] = 5
	descriptor := testDescriptor()
	descriptor.Scope.OriginID, descriptor.Scope.AccountID = "https://attacker.example", foreignAccount
	descriptor.Scope.RoomID, descriptor.Scope.OperationRevision = "voice:"+foreignAccount, 2
	if err := repository.Apply(context.Background(), principal, testLease, "https://voice.example.test", descriptor); err != nil {
		t.Fatal(err)
	}
	if publisher.calls != 1 || publisher.lease != testLease || publisher.channel != testChannel {
		t.Fatalf("publication target = %#v", publisher)
	}
	var canonical publishdescriptor.Descriptor
	if err := json.Unmarshal([]byte(publisher.body), &canonical); err != nil {
		t.Fatal(err)
	}
	if canonical.Scope.OriginID != "https://voice.example.test" || canonical.Scope.AccountID != testAccount || canonical.Scope.RoomID != "voice:"+testChannel {
		t.Fatalf("server did not replace client scope: %#v", canonical.Scope)
	}
	foreign := principal
	foreign.AccountID = foreignAccount
	if err := repository.Apply(context.Background(), foreign, testLease, "https://voice.example.test", descriptor); !errors.Is(err, publishdescriptor.ErrDenied) {
		t.Fatalf("cross-account update = %v", err)
	}
	if publisher.calls != 1 {
		t.Fatal("cross-account update reached LiveKit")
	}
}

func TestClientCannotRedirectDescriptorToAnotherChannel(t *testing.T) {
	database := &fakeDatabase{account: testAccount, channel: testChannel, lease: testLease, digest: make([]byte, 32)}
	database.digest[0] = 5
	publisher := &fakePublisher{}
	value := testDescriptor()
	value.Scope.RoomID = "voice:attacker-channel"
	principal := publishdescriptor.Principal{AccountID: testAccount}
	principal.SessionDigest[0] = 5
	if err := New(database, publisher).Apply(context.Background(), principal, testLease, "https://voice.example.test", value); err != nil {
		t.Fatal(err)
	}
	if publisher.channel != testChannel {
		t.Fatalf("client-selected channel reached LiveKit: %q", publisher.channel)
	}
}
