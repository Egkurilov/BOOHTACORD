package changemessagereactionpostgres

import (
	"github.com/google/uuid"
	"testing"
	"time"
	listpins "voice-platform/backend/internal/chat/list_text_pins"
	listpinspg "voice-platform/backend/internal/chat/list_text_pins/postgres"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	replay "voice-platform/backend/internal/realtime/replay_event/postgres"
)

func TestSocialJournalReplayKeepsDMPrivateAndRevalidatesCurrentACL(t *testing.T) {
	f := newSocialFixture(t)
	journal := replay.New(f.pool)
	epoch := uuid.NewString()
	cursor := eventhub.Event{EventID: uuid.NewString(), Kind: "channel.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"revision": 1}}
	dm := eventhub.Event{EventID: uuid.NewString(), Kind: "direct_message.reactions_updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"direct_message_id": f.dm, "message_id": f.dmMessage}}
	text := eventhub.Event{EventID: uuid.NewString(), Kind: "message.pins_updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": f.channel, "message_id": f.message}}
	for _, item := range []struct {
		event eventhub.Event
		to    []string
	}{{cursor, nil}, {dm, []string{f.a, f.b}}, {text, nil}} {
		if err := journal.Append(t.Context(), item.event, item.to, epoch); err != nil {
			t.Fatal(err)
		}
	}
	for _, actor := range []string{f.a, f.b, f.admin, f.outsider} {
		events, err := journal.Replay(t.Context(), actor, cursor.EventID, epoch, 10)
		if err != nil {
			t.Fatal(err)
		}
		private := false
		for _, event := range events {
			if len(event.Payload) != 2 {
				t.Fatal("metadata hint contains extra fields")
			}
			if event.Kind == dm.Kind {
				private = true
			}
		}
		if private != (actor == f.a || actor == f.b) {
			t.Fatal("private replay visibility differs")
		}
		allowed, err := journal.Authorize(t.Context(), actor, dm)
		if err != nil || allowed != (actor == f.a || actor == f.b) {
			t.Fatal("DM authorization differs")
		}
	}
	f.exec(t, "UPDATE users SET blocked_at=now() WHERE id=$1", f.a)
	for _, event := range []eventhub.Event{dm, text} {
		if allowed, err := journal.Authorize(t.Context(), f.a, event); err != nil || allowed {
			t.Fatal("blocked account retained replay access")
		}
	}
	f.exec(t, "UPDATE channels SET archived_at=now() WHERE id=$1", f.channel)
	if allowed, err := journal.Authorize(t.Context(), f.b, text); err != nil || allowed {
		t.Fatal("archived TEXT retained replay access")
	}
	f.exec(t, "UPDATE channels SET archived_at=NULL WHERE id=$1", f.channel)
	f.exec(t, "INSERT INTO text_message_pins(message_id,pinned_by) VALUES($1,$2)", f.message, f.admin)
	page, err := listpins.New(listpinspg.New(f.pool)).List(t.Context(), listpins.Input{ActorID: f.b, ChannelID: f.channel, Limit: 10})
	if err != nil || len(page.Pins) != 1 || page.Pins[0].AuthorID != f.a || page.Pins[0].Preview != "synthetic" || page.Pins[0].MessageCreatedAt.IsZero() {
		t.Fatal("bounded pin preview differs")
	}
}
