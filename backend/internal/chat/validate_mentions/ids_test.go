package validatementions

import "testing"

func TestValidRejectsMalformedDuplicateSelfAndOversized(t *testing.T) {
	actor := "11111111-1111-4111-8111-111111111111"
	recipient := "22222222-2222-4222-8222-222222222222"
	tooMany := make([]string, 101)
	for index := range tooMany {
		tooMany[index] = recipient
	}
	for _, ids := range [][]string{{"bad"}, {recipient, recipient}, {actor}, tooMany} {
		if Valid(ids, actor) {
			t.Fatalf("accepted invalid mentions: %#v", ids)
		}
	}
	if !Valid(nil, actor) || !Valid([]string{recipient}, actor) {
		t.Fatal("rejected valid mention list")
	}
}
