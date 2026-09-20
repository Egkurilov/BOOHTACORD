package issuelivekitcredential

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
)

func TestIssueSignsOnlyActiveLeaseFoundForCurrentSession(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	store := &fakeStore{lease: Lease{ID: "lease-1", ChannelID: "voice-1"}}
	issuer := &fakeIssuer{credential: livekitcredential.Credential{Token: "test-token"}}
	credential, err := New(store, issuer).Issue(context.Background(), Input{ActorID: "user-1", LeaseID: "lease-1", SessionDigest: digest})
	if err != nil || store.input.SessionDigest != digest || issuer.leaseID != "lease-1" || issuer.channelID != "voice-1" || issuer.accountID != "user-1" || credential.Token == "" {
		t.Fatalf("error = %v, store = %#v, issuer lease = %q", err, store.input, issuer.leaseID)
	}
}
func TestIssueRejectsUnavailableLeaseWithoutSigning(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	issuer := &fakeIssuer{}
	_, err := New(&fakeStore{err: ErrLeaseUnavailable}, issuer).Issue(context.Background(), Input{ActorID: "user-1", LeaseID: "lease-1", SessionDigest: digest})
	if !errors.Is(err, ErrLeaseUnavailable) || issuer.called {
		t.Fatalf("error = %v, issuer called = %v", err, issuer.called)
	}
}

type fakeStore struct {
	input Input
	lease Lease
	err   error
}

func (store *fakeStore) FindActive(_ context.Context, input Input) (Lease, error) {
	store.input = input
	return store.lease, store.err
}

type fakeIssuer struct {
	leaseID, channelID, accountID string
	credential         livekitcredential.Credential
	err                error
	called             bool
}

func (issuer *fakeIssuer) Issue(leaseID, channelID, accountID string) (livekitcredential.Credential, error) {
	issuer.leaseID, issuer.channelID, issuer.accountID, issuer.called = leaseID, channelID, accountID, true
	return issuer.credential, issuer.err
}
