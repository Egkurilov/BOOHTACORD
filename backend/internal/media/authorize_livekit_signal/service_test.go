package authorizelivekitsignal

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/livekit/protocol/auth"
)

const (
	testAPIKey    = "test-key"
	testAPISecret = "test-secret"
	testLeaseID   = "11111111-1111-4111-8111-111111111111"
	testChannelID = "22222222-2222-4222-8222-222222222222"
)

func TestAdmitVerifiesCurrentLeaseScopedSignalToken(t *testing.T) {
	store := &fakeStore{}
	service, err := New(Config{APIKey: testAPIKey, APISecret: testAPISecret}, store)
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	if err := service.Admit(context.Background(), "/rtc?access_token="+token(t, &auth.VideoGrant{RoomJoin: true, Room: "voice:" + testChannelID}), ""); err != nil {
		t.Fatalf("Admit() error = %v", err)
	}
	if !store.called || store.leaseID != testLeaseID || store.channelID != testChannelID {
		t.Fatalf("store = %#v", store)
	}
}

func TestAdmitAcceptsNativeBearerSignalToken(t *testing.T) {
	store := &fakeStore{}
	service, err := New(Config{APIKey: testAPIKey, APISecret: testAPISecret}, store)
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	value := token(t, &auth.VideoGrant{RoomJoin: true, Room: "voice:" + testChannelID})
	if err := service.Admit(context.Background(), "/rtc", "Bearer "+value); err != nil {
		t.Fatalf("Admit() error = %v", err)
	}
	if !store.called || store.leaseID != testLeaseID || store.channelID != testChannelID {
		t.Fatalf("store = %#v", store)
	}
}

func TestAdmitRejectsInvalidOrOverprivilegedSignalTokens(t *testing.T) {
	service, err := New(Config{APIKey: testAPIKey, APISecret: testAPISecret}, &fakeStore{})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	valid := token(t, &auth.VideoGrant{RoomJoin: true, Room: "voice:" + testChannelID})
	expiredToken := expiredToken(t)
	for name, input := range map[string]struct{ uri, authorization string }{
		"missing token":         {uri: "/rtc"},
		"duplicated token":      {uri: "/rtc?access_token=" + valid + "&access_token=" + valid},
		"both transports":       {uri: "/rtc?access_token=" + valid, authorization: "Bearer " + valid},
		"malformed bearer":      {uri: "/rtc", authorization: "bearer " + valid},
		"spaced bearer":         {uri: "/rtc", authorization: "Bearer " + valid + " trailing"},
		"wrong path":            {uri: "/not-rtc?access_token=" + valid},
		"malformed token":       {uri: "/rtc?access_token=not-a-jwt"},
		"expired token":         {uri: "/rtc?access_token=" + expiredToken},
		"room admin credential": {uri: "/rtc?access_token=" + token(t, &auth.VideoGrant{RoomJoin: true, RoomAdmin: true, Room: "voice:" + testChannelID})},
		"wrong room":            {uri: "/rtc?access_token=" + token(t, &auth.VideoGrant{RoomJoin: true, Room: "other:" + testChannelID})},
	} {
		t.Run(name, func(t *testing.T) {
			if err := service.Admit(context.Background(), input.uri, input.authorization); !errors.Is(err, ErrDenied) {
				t.Fatalf("Admit() error = %v, want ErrDenied", err)
			}
		})
	}
}

func token(t *testing.T, grant *auth.VideoGrant) string {
	t.Helper()
	value, err := auth.NewAccessToken(testAPIKey, testAPISecret).
		SetIdentity("voice-lease:" + testLeaseID).
		SetVideoGrant(grant).
		SetValidFor(time.Minute).
		ToJWT()
	if err != nil {
		t.Fatalf("ToJWT() error = %v", err)
	}
	return value
}

func expiredToken(t *testing.T) string {
	t.Helper()
	value := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iss":      testAPIKey,
		"sub":      "voice-lease:" + testLeaseID,
		"identity": "voice-lease:" + testLeaseID,
		"exp":      time.Now().Add(-time.Minute).Unix(),
		"video": map[string]any{
			"roomJoin": true,
			"room":     "voice:" + testChannelID,
		},
	})
	raw, err := value.SignedString([]byte(testAPISecret))
	if err != nil {
		t.Fatalf("SignedString() error = %v", err)
	}
	return raw
}

type fakeStore struct {
	leaseID, channelID string
	called             bool
}

func (store *fakeStore) Admit(_ context.Context, leaseID, channelID string) error {
	store.leaseID, store.channelID, store.called = leaseID, channelID, true
	return nil
}
