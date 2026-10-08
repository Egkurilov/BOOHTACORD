package changemessagereactionpostgres

import (
	"errors"
	"testing"
	action "voice-platform/backend/internal/chat/change_message_reaction"
	pin "voice-platform/backend/internal/chat/change_text_pin"
	pinpg "voice-platform/backend/internal/chat/change_text_pin/postgres"
	deleteDM "voice-platform/backend/internal/chat/delete_direct_message"
	deleteDMpg "voice-platform/backend/internal/chat/delete_direct_message/postgres"
	deleteText "voice-platform/backend/internal/chat/delete_text_message"
	deleteTextpg "voice-platform/backend/internal/chat/delete_text_message/postgres"
)

func TestRealMessageDeletesAtomicallyClearReactionsPinsAndRejectResurrection(t *testing.T) {
	f := newSocialFixture(t)
	writer := action.New(New(f.pool))
	in := action.Input{ActorID: f.a, ConversationID: f.channel, MessageID: f.message, Emoji: "👀", Present: true}
	if _, err := writer.Set(t.Context(), in); err != nil {
		t.Fatal(err)
	}
	if _, err := pin.New(pinpg.New(f.pool)).Set(t.Context(), pin.Input{ActorID: f.admin, ChannelID: f.channel, MessageID: f.message, Present: true}); err != nil {
		t.Fatal(err)
	}
	if _, err := deleteText.New(deleteTextpg.New(deleteTextpg.NewPoolDatabase(f.pool))).Delete(t.Context(), deleteText.Input{ActorID: f.a, ActorRole: "MEMBER", ChannelID: f.channel, MessageID: f.message}); err != nil {
		t.Fatal(err)
	}
	if f.count(t, "text_message_reactions", f.message) != 0 || f.count(t, "text_message_pins", f.message) != 0 {
		t.Fatal("TEXT metadata survived delete")
	}
	if _, err := writer.Set(t.Context(), in); !errors.Is(err, action.ErrUnavailable) {
		t.Fatal("TEXT reaction resurrected")
	}
	in.ConversationID = f.dm
	in.MessageID = f.dmMessage
	in.Direct = true
	if _, err := writer.Set(t.Context(), in); err != nil {
		t.Fatal(err)
	}
	if _, err := deleteDM.New(deleteDMpg.New(deleteDMpg.NewPoolDatabase(f.pool))).Delete(t.Context(), deleteDM.Input{ActorID: f.a, DirectMessageID: f.dm, MessageID: f.dmMessage}); err != nil {
		t.Fatal(err)
	}
	if f.count(t, "direct_message_reactions", f.dmMessage) != 0 {
		t.Fatal("DM metadata survived delete")
	}
	if _, err := writer.Set(t.Context(), in); !errors.Is(err, action.ErrUnavailable) {
		t.Fatal("DM reaction resurrected")
	}
}
