package managevoicetimeout

import (
	"context"
	"errors"
	"testing"
	"time"
)

type storeStub struct {
	calls int
	err   error
	input Input
}

func (s *storeStub) Set(_ context.Context, in Input) (State, error) {
	s.calls++
	s.input = in
	return State{Active: true}, s.err
}
func (s *storeStub) Clear(_ context.Context, in Input) (State, error) {
	s.calls++
	return State{}, s.err
}
func (s *storeStub) Read(_ context.Context, in Input) (State, error) {
	s.calls++
	return State{}, s.err
}

func TestValidationRejectsUnboundedReasonsBeforeStore(t *testing.T) {
	for _, reason := range []string{"", "user supplied private text", "disruption"} {
		s := &storeStub{}
		in := validInput()
		in.Reason = reason
		if _, err := New(s).Set(t.Context(), in); !errors.Is(err, ErrInvalidInput) || s.calls != 0 {
			t.Fatalf("err=%v calls=%d", err, s.calls)
		}
	}
}
func TestTimeoutServicePreservesACLAndSessionDenial(t *testing.T) {
	for _, want := range []error{ErrForbidden, ErrUnauthenticated, ErrNotFound, ErrInvalidInput} {
		s := &storeStub{err: want}
		if _, err := New(s).Set(t.Context(), validInput()); !errors.Is(err, want) {
			t.Fatalf("err=%v", err)
		}
	}
}
func TestOnlyAbsoluteExpiryAndAuthenticatedIdentityReachStore(t *testing.T) {
	s := &storeStub{}
	in := validInput()
	in.ExpiresAt = time.Time{}
	if _, err := New(s).Set(t.Context(), in); !errors.Is(err, ErrInvalidInput) || s.calls != 0 {
		t.Fatal("zero expiry accepted")
	}
	in = validInput()
	in.SessionDigest = [32]byte{}
	if _, err := New(s).Clear(t.Context(), in); !errors.Is(err, ErrInvalidInput) || s.calls != 0 {
		t.Fatal("missing session accepted")
	}
	in = validInput()
	if _, err := New(s).Set(t.Context(), in); err != nil || s.calls != 1 {
		t.Fatal(err)
	}
	if s.input.ExpiresAt.Location() != time.UTC || s.input.ExpiresAt.Nanosecond()%1000 != 0 {
		t.Fatal("expiry must use PG precision and UTC")
	}
}
func validInput() Input {
	return Input{ActorID: "00112233-4455-6677-8899-aabbccddeeff", TargetID: "10112233-4455-6677-8899-aabbccddeeff", SessionDigest: [32]byte{1}, Reason: "DISRUPTION", ExpiresAt: time.Now().Add(time.Hour)}
}
