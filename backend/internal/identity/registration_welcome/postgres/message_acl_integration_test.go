package welcomepostgres

import (
	"bytes"
	"errors"
	"github.com/google/uuid"
	"go.opentelemetry.io/otel/metric/noop"
	tracenoop "go.opentelemetry.io/otel/trace/noop"
	"testing"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	createpostgres "voice-platform/backend/internal/chat/create_text_message/postgres"
	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
	deletepostgres "voice-platform/backend/internal/chat/delete_text_message/postgres"
	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
	editpostgres "voice-platform/backend/internal/chat/edit_text_message/postgres"
	registeruser "voice-platform/backend/internal/identity/register_user"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestWelcomeUsesServerMessageACL(t *testing.T) {
	f := guildfixture.New(t)
	if _, err := f.Pool.Exec(f.Context, `UPDATE guild_settings SET welcome_channel_id=$1 WHERE singleton=TRUE`, f.Channel); err != nil {
		t.Fatal(err)
	}
	observer := guildlifecycle.New(tracenoop.NewTracerProvider().Tracer("test"), noop.NewMeterProvider().Meter("test"), nil)
	account := registeruser.Account{ID: uuid.NewString(), Login: "subject", DisplayName: "Subject", Role: registeruser.RoleMember, PasswordHash: "test"}
	repo := Repository{Database: f.Pool, Observer: observer, Events: &publisher{}, Random: bytes.NewReader(make([]byte, 32))}
	if err := repo.Create(f.Context, account); err != nil {
		t.Fatal(err)
	}
	var id string
	if err := f.Pool.QueryRow(f.Context, `SELECT id::text FROM messages WHERE author_id=$1`, account.ID).Scan(&id); err != nil {
		t.Fatal(err)
	}
	_, err := editpostgres.New(editpostgres.NewPoolDatabase(f.Pool)).Edit(f.Context, edittextmessage.Request{Input: edittextmessage.Input{ActorID: account.ID, ChannelID: f.Channel, MessageID: id, Body: "edit", ExpectedRevision: 1}})
	if !errors.Is(err, edittextmessage.ErrConflict) {
		t.Fatal("subject edited system welcome")
	}
	_, err = createpostgres.New(createpostgres.NewPoolDatabase(f.Pool)).Create(f.Context, createtextmessage.Request{ID: uuid.NewString(), Input: createtextmessage.Input{ActorID: account.ID, ChannelID: f.Channel, ClientMessageID: uuid.NewString(), ReplyToID: id, Body: "reply"}})
	if !errors.Is(err, createtextmessage.ErrChannelUnavailable) {
		t.Fatal("reply to system welcome accepted")
	}
	deleter := deletepostgres.New(deletepostgres.NewPoolDatabase(f.Pool))
	_, err = deleter.Delete(f.Context, deletetextmessage.Request{Input: deletetextmessage.Input{ActorID: account.ID, ActorRole: "MEMBER", ChannelID: f.Channel, MessageID: id}})
	if !errors.Is(err, deletetextmessage.ErrDeleteDenied) {
		t.Fatal("subject deleted welcome")
	}
	if _, err = deleter.Delete(f.Context, deletetextmessage.Request{Input: deletetextmessage.Input{ActorID: f.Admin, ActorRole: "ADMINISTRATOR", ChannelID: f.Channel, MessageID: id}}); err != nil {
		t.Fatal("administrator could not delete welcome")
	}
}
