package managevoicetimeoutpostgres

import (
	"github.com/google/uuid"
	"testing"
	"time"
	signal "voice-platform/backend/internal/media/authorize_livekit_signal"
	signalpg "voice-platform/backend/internal/media/authorize_livekit_signal/postgres"
	credential "voice-platform/backend/internal/media/issue_livekit_credential"
	credentialpg "voice-platform/backend/internal/media/issue_livekit_credential/postgres"
	guild "voice-platform/backend/internal/testsupport/guild_lifecycle"
	acquire "voice-platform/backend/internal/voice/acquire_voice_lease"
	acquirepg "voice-platform/backend/internal/voice/acquire_voice_lease/postgres"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

type fixture struct {
	guild.Fixture
	member, lease             string
	adminDigest, memberDigest [32]byte
	input                     timeout.Input
	repo                      Repository
}

func newFixture(t *testing.T) fixture {
	t.Helper()
	f := fixture{Fixture: guild.New(t), member: uuid.NewString(), lease: uuid.NewString(), adminDigest: [32]byte{11}, memberDigest: [32]byte{12}}
	for _, s := range []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO users(id,login,display_name,role,password_hash)VALUES($1,'timeout-member','Member','MEMBER','synthetic')`, []any{f.member}},
		{`INSERT INTO sessions(token_digest,user_id)VALUES($1,$2),($3,$4)`, []any{f.adminDigest[:], f.Admin, f.memberDigest[:], f.member}},
		{`INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest)VALUES($1,$2,$3,$4)`, []any{f.lease, f.member, f.Voice, f.memberDigest[:]}},
	} {
		if _, err := f.Pool.Exec(f.Context, s.sql, s.args...); err != nil {
			t.Fatal(err)
		}
	}
	f.input = timeout.Input{ActorID: f.Admin, TargetID: f.member, SessionDigest: f.adminDigest, ExpiresAt: time.Now().Add(time.Hour).UTC().Truncate(time.Microsecond), Reason: "DISRUPTION"}
	f.repo = New(f.Pool)
	return f
}
func (f fixture) acquire() (acquire.Result, error) {
	return acquirepg.New(acquirepg.NewPoolDatabase(f.Pool)).Acquire(f.Context, acquire.Request{ID: uuid.NewString(), Input: acquire.Input{ActorID: f.member, ChannelID: f.Voice, SessionDigest: f.memberDigest, Transfer: true}})
}
func (f fixture) credential() error {
	_, err := credentialpg.New(credentialpg.NewPoolDatabase(f.Pool)).FindActive(f.Context, credential.Input{ActorID: f.member, LeaseID: f.lease, SessionDigest: f.memberDigest})
	return err
}
func (f fixture) signal() error {
	return signalpg.New(signalpg.NewPoolDatabase(f.Pool)).Admit(f.Context, f.lease, f.Voice)
}
func (f fixture) assertRevoked(t *testing.T) {
	t.Helper()
	var active, queued int
	if err := f.Pool.QueryRow(f.Context, `SELECT COUNT(*)FILTER(WHERE revoked_at IS NULL)FROM voice_leases WHERE user_id=$1`, f.member).Scan(&active); err != nil {
		t.Fatal(err)
	}
	if err := f.Pool.QueryRow(f.Context, `SELECT COUNT(*)FROM voice_sfu_revocations WHERE lease_id=$1`, f.lease).Scan(&queued); err != nil {
		t.Fatal(err)
	}
	if active != 0 || queued != 1 {
		t.Fatalf("active=%d queued=%d", active, queued)
	}
	if err := f.credential(); err != credential.ErrLeaseUnavailable {
		t.Fatalf("credential=%v", err)
	}
	if err := f.signal(); err != signal.ErrDenied {
		t.Fatalf("signal=%v", err)
	}
}
