package changemessagereactionpostgres

import (
	"testing"
	action "voice-platform/backend/internal/chat/change_message_reaction"
	pin "voice-platform/backend/internal/chat/change_text_pin"
	pinpg "voice-platform/backend/internal/chat/change_text_pin/postgres"
	list "voice-platform/backend/internal/chat/list_message_reactions"
	listpg "voice-platform/backend/internal/chat/list_message_reactions/postgres"
	listpins "voice-platform/backend/internal/chat/list_text_pins"
	listpinspg "voice-platform/backend/internal/chat/list_text_pins/postgres"
)

func TestReactionAndPinDesiredStatesAreIdempotentAndCountsDoNotExposeActors(t *testing.T) {
	f := newSocialFixture(t)
	s := action.New(New(f.pool))
	in := action.Input{ActorID: f.a, ConversationID: f.channel, MessageID: f.message, Emoji: "👍", Present: true}
	for i := 0; i < 2; i++ {
		result, err := s.Set(t.Context(), in)
		if err != nil || result.Changed != (i == 0) {
			t.Fatalf("put replay changed=%v err=%v", result.Changed, err)
		}
	}
	in.ActorID = f.b
	if _, err := s.Set(t.Context(), in); err != nil {
		t.Fatal(err)
	}
	rows, err := list.New(listpg.New(f.pool)).List(t.Context(), list.Input{ActorID: f.a, ConversationID: f.channel, MessageIDs: []string{f.message}})
	if err != nil || len(rows) != 1 || rows[0].Count != 2 || !rows[0].Mine {
		t.Fatal("reaction aggregate differs")
	}
	in.ActorID = f.a
	in.Present = false
	for i := 0; i < 2; i++ {
		result, err := s.Set(t.Context(), in)
		if err != nil || result.Changed != (i == 0) {
			t.Fatal("delete replay differs")
		}
	}
	if f.count(t, "text_message_reactions", f.message) != 1 {
		t.Fatal("duplicate or wrong actor deleted")
	}
	p := pin.New(pinpg.New(f.pool))
	input := pin.Input{ActorID: f.admin, ChannelID: f.channel, MessageID: f.message, Present: true}
	for i := 0; i < 2; i++ {
		result, err := p.Set(t.Context(), input)
		if err != nil || result.Changed != (i == 0) {
			t.Fatal("pin replay differs")
		}
	}
	input.MessageID = f.second
	if _, err := p.Set(t.Context(), input); err != nil {
		t.Fatal(err)
	}
	lister := listpins.New(listpinspg.New(f.pool))
	page, err := lister.List(t.Context(), listpins.Input{ActorID: f.a, ChannelID: f.channel, Limit: 1})
	if err != nil || len(page.Pins) != 1 || page.NextCursor == "" {
		t.Fatal("pin page differs")
	}
	next, err := lister.List(t.Context(), listpins.Input{ActorID: f.a, ChannelID: f.channel, Limit: 1, Before: page.NextCursor})
	if err != nil || len(next.Pins) != 1 || next.Pins[0].MessageID == page.Pins[0].MessageID {
		t.Fatal("pin cursor duplicated entry")
	}
	input.MessageID = f.message
	input.Present = false
	for i := 0; i < 2; i++ {
		result, err := p.Set(t.Context(), input)
		if err != nil || result.Changed != (i == 0) {
			t.Fatal("unpin replay differs")
		}
	}
}
