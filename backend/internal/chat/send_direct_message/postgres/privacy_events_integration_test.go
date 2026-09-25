package senddirectmessagepostgres

import (
	"context"
	"testing"

	"github.com/google/uuid"
	deleteDM "voice-platform/backend/internal/chat/delete_direct_message"
	deletepostgres "voice-platform/backend/internal/chat/delete_direct_message/postgres"
	deleterealtime "voice-platform/backend/internal/chat/delete_direct_message/realtime"
	edit "voice-platform/backend/internal/chat/edit_direct_message"
	editpostgres "voice-platform/backend/internal/chat/edit_direct_message/postgres"
	editrealtime "voice-platform/backend/internal/chat/edit_direct_message/realtime"
	send "voice-platform/backend/internal/chat/send_direct_message"
	sendrealtime "voice-platform/backend/internal/chat/send_direct_message/realtime"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	recipients "voice-platform/backend/internal/realtime/resolve_direct_message_recipients/postgres"
)

func TestDMCreateEditDeleteHintsReachOnlyCurrentPairInPostgres(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	hub := eventhub.New(8)
	actor := hub.Subscribe(f.actor)
	peer := hub.Subscribe(f.peer)
	admin := hub.Subscribe(f.outsider)
	defer actor.Close()
	defer peer.Close()
	defer admin.Close()
	resolver := recipients.New(recipients.NewPoolDatabase(f.pool))
	sender := sendrealtime.New(send.New(New(NewPoolDatabase(f.pool))), resolver, hub)
	message, err := sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "private fixture"})
	if err != nil {
		t.Fatal(err)
	}
	assertPrivateHint(t, actor, peer, admin, "direct_message.message_created", 2)
	editor := editrealtime.New(edit.New(editpostgres.New(editpostgres.NewPoolDatabase(f.pool))), resolver, hub)
	_, err = editor.Edit(ctx, edit.Input{ActorID: f.actor, DirectMessageID: f.pair, MessageID: message.ID, Body: "edited fixture", ExpectedRevision: 1})
	if err != nil {
		t.Fatal(err)
	}
	assertPrivateHint(t, actor, peer, admin, "direct_message.message_updated", 3)
	deleter := deleterealtime.New(deleteDM.New(deletepostgres.New(deletepostgres.NewPoolDatabase(f.pool))), resolver, hub)
	_, err = deleter.Delete(ctx, deleteDM.Input{ActorID: f.actor, DirectMessageID: f.pair, MessageID: message.ID})
	if err != nil {
		t.Fatal(err)
	}
	assertPrivateHint(t, actor, peer, admin, "direct_message.message_deleted", 3)
	if _, err := f.pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, f.peer); err != nil {
		t.Fatal(err)
	}
	active, err := resolver.Resolve(ctx, f.pair, f.actor)
	if err != nil || len(active) != 1 || active[0] != f.actor {
		t.Fatalf("blocked recipient was not removed: count=%d err=%v", len(active), err)
	}
	foreign, err := resolver.Resolve(ctx, f.pair, f.outsider)
	if err != nil || len(foreign) != 0 {
		t.Fatalf("foreign administrator resolved recipients: count=%d err=%v", len(foreign), err)
	}
}

func assertPrivateHint(t *testing.T, actor, peer, admin *eventhub.Subscription, kind string, payloadSize int) {
	t.Helper()
	for _, subscription := range []*eventhub.Subscription{actor, peer} {
		select {
		case event := <-subscription.Events():
			if event.Kind != kind || len(event.Payload) != payloadSize || event.Payload["body"] != nil || event.Payload["author_id"] != nil {
				t.Fatal("private hint was missing or carried content")
			}
		default:
			t.Fatal("participant did not receive private hint")
		}
	}
	select {
	case <-admin.Events():
		t.Fatal("nonparticipant administrator received private hint")
	default:
	}
}
