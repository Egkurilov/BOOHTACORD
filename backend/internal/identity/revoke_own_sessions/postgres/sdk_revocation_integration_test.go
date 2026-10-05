package revokesessionpostgres

import (
	"crypto/sha256"
	"errors"
	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"testing"
	"time"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
	signal "voice-platform/backend/internal/media/authorize_livekit_signal"
	signalpostgres "voice-platform/backend/internal/media/authorize_livekit_signal/postgres"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestPreviouslyIssuedSDKCredentialIsDeniedAfterOwnSessionRevocation(t *testing.T) {
	f := guildfixture.New(t)
	current, old := sha256.Sum256([]byte("initiating-sdk-fixture")), sha256.Sum256([]byte("revoked-sdk-fixture"))
	for _, digest := range [][32]byte{current, old} {
		if _, err := f.Pool.Exec(f.Context, `INSERT INTO sessions(user_id,token_digest) VALUES($1,$2)`, f.Admin, digest[:]); err != nil {
			t.Fatal(err)
		}
	}
	lease := uuid.NewString()
	if _, err := f.Pool.Exec(f.Context, `INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)`, lease, f.Admin, f.Voice, old[:]); err != nil {
		t.Fatal(err)
	}
	config := signal.Config{APIKey: "synthetic-fixture-key", APISecret: "synthetic-fixture-signing-key"}
	token, err := auth.NewAccessToken(config.APIKey, config.APISecret).SetIdentity("voice-lease:" + lease).SetValidFor(time.Minute).SetVideoGrant(&auth.VideoGrant{RoomJoin: true, Room: "voice:" + f.Voice}).ToJWT()
	if err != nil {
		t.Fatal("fixture credential creation failed")
	}
	admission, err := signal.New(config, signalpostgres.New(signalpostgres.NewPoolDatabase(f.Pool)))
	if err != nil {
		t.Fatal(err)
	}
	if err = admission.Admit(f.Context, "/rtc", "Bearer "+token); err != nil {
		t.Fatal("fixture credential was not initially admissible")
	}
	if _, err = New(f.Pool).Revoke(f.Context, revoke.Input{AccountID: f.Admin, Current: current, Others: true}); err != nil {
		t.Fatal(err)
	}
	if err = admission.Admit(f.Context, "/rtc", "Bearer "+token); !errors.Is(err, signal.ErrDenied) {
		t.Fatal("old SDK credential still admits signalling")
	}
}
