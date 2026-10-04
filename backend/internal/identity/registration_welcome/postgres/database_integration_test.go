package welcomepostgres

import (
	"bytes"
	"github.com/google/uuid"
	"go.opentelemetry.io/otel/metric/noop"
	tracenoop "go.opentelemetry.io/otel/trace/noop"
	"testing"
	registeruser "voice-platform/backend/internal/identity/register_user"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestAccountAndWelcomeCommitTogetherAndWelcomeIsImmutable(t *testing.T) {
	f := guildfixture.New(t)
	if _, err := f.Pool.Exec(f.Context, `UPDATE guild_settings SET welcome_channel_id=$1 WHERE singleton=TRUE`, f.Channel); err != nil {
		t.Fatal(err)
	}
	observer := guildlifecycle.New(tracenoop.NewTracerProvider().Tracer("test"), noop.NewMeterProvider().Meter("test"), nil)
	repo := Repository{Database: f.Pool, Observer: observer, Events: &publisher{}, Random: bytes.NewReader(make([]byte, 32))}
	account := registeruser.Account{ID: uuid.NewString(), Login: "newmember", DisplayName: "NewMember", Role: registeruser.RoleMember, PasswordHash: "test-hash"}
	if err := repo.Create(f.Context, account); err != nil {
		t.Fatal(err)
	}
	var message, kind, body string
	var mentions []string
	if err := f.Pool.QueryRow(f.Context, `SELECT id::text,kind,body,mention_user_ids::text[] FROM messages WHERE author_id=$1`, account.ID).Scan(&message, &kind, &body, &mentions); err != nil {
		t.Fatal(err)
	}
	if kind != "SYSTEM_WELCOME" || body == "" || len(mentions) != 1 || mentions[0] != account.ID {
		t.Fatal("welcome shape mismatch")
	}
	for _, statement := range []string{
		`UPDATE messages SET body='edited' WHERE id=$1`,
		`UPDATE messages SET edited_at=now() WHERE id=$1`,
		`INSERT INTO messages(id,channel_id,author_id,client_message_id,body,reply_to_id) SELECT gen_random_uuid(),channel_id,author_id,gen_random_uuid(),'reply',id FROM messages WHERE id=$1`,
		`INSERT INTO messages(id,channel_id,author_id,client_message_id,body,kind,mention_user_ids) SELECT gen_random_uuid(),channel_id,author_id,gen_random_uuid(),body,kind,mention_user_ids FROM messages WHERE id=$1`,
	} {
		if _, err := f.Pool.Exec(f.Context, statement, message); err == nil {
			t.Fatal("immutable welcome or unique account invariant bypassed")
		}
	}
	// Inject a welcome insertion failure, and assert the account is absent too.
	if _, err := f.Pool.Exec(f.Context, `CREATE FUNCTION fail_test_welcome() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected failure'; END; $$;
 CREATE TRIGGER fail_test_welcome BEFORE INSERT ON messages FOR EACH ROW EXECUTE FUNCTION fail_test_welcome()`); err != nil {
		t.Fatal(err)
	}
	account.ID, account.Login = uuid.NewString(), "rollback"
	repo.Random = bytes.NewReader(make([]byte, 32))
	if err := repo.Create(f.Context, account); err == nil {
		t.Fatal("injected database failure ignored")
	}
	var exists bool
	if err := f.Pool.QueryRow(f.Context, `SELECT EXISTS(SELECT 1 FROM users WHERE id=$1)`, account.ID).Scan(&exists); err != nil || exists {
		t.Fatal("welcome failure left orphan registration")
	}
}
