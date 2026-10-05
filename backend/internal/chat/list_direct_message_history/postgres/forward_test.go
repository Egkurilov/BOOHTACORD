package listdirectmessagehistorypostgres

import (
	"context"
	"strings"
	"testing"
	list "voice-platform/backend/internal/chat/list_direct_message_history"
)

func TestForwardPreservesParticipantScopeAndExclusiveTupleOrder(t *testing.T) {
	db := &fakeDatabase{available: boolRow{value: true}, rows: &fakeRows{}}
	_, err := New(db).List(context.Background(), list.Request{Input: list.Input{ActorID: actorID, DirectMessageID: directMessageID, After: actorID, Limit: 20}})
	for _, fragment := range []string{"$2::uuid IN (dm.participant_one_id, dm.participant_two_id)", "(SELECT id FROM readable_pair)", "(m.created_at, m.id) >", "ORDER BY m.created_at ASC, m.id ASC"} {
		if !strings.Contains(db.statement, fragment) {
			t.Fatal("forward query lost participant ACL or tuple order")
		}
	}
	if err != nil || db.arguments[2] != actorID || db.arguments[3] != 21 || db.arguments[4] != false {
		t.Fatal("incorrect forward parameters", err)
	}
}
