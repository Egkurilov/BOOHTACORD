package deliverypostgres

import (
	"errors"
	"github.com/google/uuid"
	"testing"
	delivery "voice-platform/backend/internal/chat/lookup_message_delivery"
	fixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestDeliveryReceiptBelongsToAuthorAndAccessibleConversation(t *testing.T) {
	f := fixture.New(t)
	peer := uuid.NewString()
	if _, err := f.Pool.Exec(f.Context, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'peer','Peer','fixture','MEMBER')`, peer); err != nil {
		t.Fatal(err)
	}
	client, message := uuid.NewString(), uuid.NewString()
	if _, err := f.Pool.Exec(f.Context, `INSERT INTO messages(id,channel_id,author_id,client_message_id,body) VALUES($1,$2,$3,$4,'fixture')`, message, f.Channel, peer, client); err != nil {
		t.Fatal(err)
	}
	repository := New(f.Pool)
	input := delivery.Input{ActorID: peer, ConversationID: f.Channel, ClientMessageID: client}
	result, err := repository.Lookup(f.Context, input)
	if err != nil || result == nil || *result != message {
		t.Fatal("committed delivery was not found", err)
	}
	input.ActorID = f.Admin
	if result, err = repository.Lookup(f.Context, input); err != nil || result != nil {
		t.Fatal("administrator received another author's receipt", err)
	}
	input.ActorID = peer
	if _, err = f.Pool.Exec(f.Context, `UPDATE messages SET deleted_at=now(),body='' WHERE id=$1`, message); err != nil {
		t.Fatal(err)
	}
	if result, err = repository.Lookup(f.Context, input); err != nil || result == nil {
		t.Fatal("deleted committed message became resendable", err)
	}
	pair := uuid.NewString()
	if _, err = f.Pool.Exec(f.Context, `INSERT INTO direct_messages(id,participant_one_id,participant_two_id) VALUES($1,LEAST($2::uuid,$3::uuid),GREATEST($2::uuid,$3::uuid))`, pair, peer, f.Admin); err != nil {
		t.Fatal(err)
	}
	if _, err = f.Pool.Exec(f.Context, `INSERT INTO direct_message_messages(id,direct_message_id,author_id,client_message_id,body) VALUES($1,$2,$3,$4,'fixture')`, message, pair, peer, client); err != nil {
		t.Fatal(err)
	}
	input.ConversationID = pair
	input.Direct = true
	if result, err = repository.Lookup(f.Context, input); err != nil || result == nil {
		t.Fatal("owned DM delivery missing", err)
	}
	input.ActorID = uuid.NewString()
	if _, err = repository.Lookup(f.Context, input); !errors.Is(err, delivery.ErrUnavailable) {
		t.Fatal("foreign DM existence leaked", err)
	}
}
