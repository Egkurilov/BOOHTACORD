package changemessagereactionpostgres

import (
	"errors"
	"testing"
	action "voice-platform/backend/internal/chat/change_message_reaction"
	pin "voice-platform/backend/internal/chat/change_text_pin"
	pinpg "voice-platform/backend/internal/chat/change_text_pin/postgres"
	list "voice-platform/backend/internal/chat/list_message_reactions"
	listpg "voice-platform/backend/internal/chat/list_message_reactions/postgres"
	listpins "voice-platform/backend/internal/chat/list_text_pins"
	listpinspg "voice-platform/backend/internal/chat/list_text_pins/postgres"
)

func TestReactionPrivacyBlocksOutsiderAdminBlockedAndWrongConversation(t *testing.T) {
	f := newSocialFixture(t)
	writer := action.New(New(f.pool))
	reader := list.New(listpg.New(f.pool))
	in := action.Input{ActorID: f.a, ConversationID: f.dm, MessageID: f.dmMessage, Emoji: "❤️", Direct: true, Present: true}
	if result, err := writer.Set(t.Context(), in); err != nil || len(result.Recipients) != 2 {
		t.Fatal("valid DM reaction denied")
	}
	for _, actor := range []string{f.admin, f.outsider, f.blocked} {
		in.ActorID = actor
		if _, err := writer.Set(t.Context(), in); !errors.Is(err, action.ErrUnavailable) {
			t.Fatal("DM write leaked access")
		}
		if _, err := reader.List(t.Context(), list.Input{ActorID: actor, ConversationID: f.dm, MessageIDs: []string{f.dmMessage}, Direct: true}); !errors.Is(err, list.ErrUnavailable) {
			t.Fatal("DM read leaked access")
		}
	}
	rows, err := reader.List(t.Context(), list.Input{ActorID: f.b, ConversationID: f.dm, MessageIDs: []string{f.foreignMessage}, Direct: true})
	if err != nil || len(rows) != 0 {
		t.Fatal("foreign DM target leaked metadata")
	}
	in.ActorID = f.b
	in.MessageID = f.foreignMessage
	if _, err := writer.Set(t.Context(), in); !errors.Is(err, action.ErrUnavailable) {
		t.Fatal("foreign DM write accepted")
	}
	in = action.Input{ActorID: f.blocked, ConversationID: f.channel, MessageID: f.message, Emoji: "✅", Present: true}
	if _, err := writer.Set(t.Context(), in); !errors.Is(err, action.ErrUnavailable) {
		t.Fatal("blocked write accepted")
	}
	in.ActorID = f.a
	for _, conversation := range []string{f.archived, f.voice} {
		in.ConversationID = conversation
		if _, err := writer.Set(t.Context(), in); !errors.Is(err, action.ErrUnavailable) {
			t.Fatal("wrong channel accepted")
		}
	}
	p := pin.New(pinpg.New(f.pool))
	for _, actor := range []string{f.a, f.blocked} {
		if _, err := p.Set(t.Context(), pin.Input{ActorID: actor, ChannelID: f.channel, MessageID: f.message, Present: true}); !errors.Is(err, pin.ErrUnavailable) {
			t.Fatal("nonadmin pin accepted")
		}
	}
	if _, err := p.Set(t.Context(), pin.Input{ActorID: f.admin, ChannelID: f.dm, MessageID: f.dmMessage, Present: true}); !errors.Is(err, pin.ErrUnavailable) {
		t.Fatal("DM pin accepted")
	}
	if _, err := listpins.New(listpinspg.New(f.pool)).List(t.Context(), listpins.Input{ActorID: f.blocked, ChannelID: f.channel, Limit: 20}); !errors.Is(err, listpins.ErrUnavailable) {
		t.Fatal("blocked pin read accepted")
	}
	f.exec(t, "UPDATE channels SET archived_at=now() WHERE id=$1", f.channel)
	in.ConversationID = f.channel
	if _, err := writer.Set(t.Context(), in); !errors.Is(err, action.ErrUnavailable) {
		t.Fatal("archived message accepted")
	}
	if _, err := reader.List(t.Context(), list.Input{ActorID: f.a, ConversationID: f.channel, MessageIDs: []string{f.message}}); !errors.Is(err, list.ErrUnavailable) {
		t.Fatal("archived reaction read accepted")
	}
}
