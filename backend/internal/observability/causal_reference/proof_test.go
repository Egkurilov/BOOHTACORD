package causalreference

import (
	"strings"
	"testing"
	"time"
)

func TestAudienceExpiryForgeryAndDurableRoundTrip(t *testing.T) {
	now := time.Now()
	cause := Cause{strings.Repeat("1", 32), strings.Repeat("2", 16), strings.Repeat("3", 32), 1}
	token := Sign("synthetic-key", "recipient", cause, now)
	for _, check := range []struct {
		key, account, value string
		at                  time.Time
		ok                  bool
	}{
		{"synthetic-key", "recipient", token, now, true}, {"synthetic-key", "other", token, now, false},
		{"synthetic-key", "recipient", token + "x", now, false}, {"other-key", "recipient", token, now, false},
		{"synthetic-key", "recipient", token, now.Add(8 * 24 * time.Hour), false},
	} {
		got, ok := Verify(check.key, check.account, check.value, check.at)
		if ok != check.ok || ok && got != cause {
			t.Fatal("proof did not enforce audience/expiry")
		}
	}
	if Decode(cause.Bytes()) != cause || Decode([]byte("bad")).Valid() {
		t.Fatal("durable cause changed")
	}
	if strings.Contains(token, "recipient") || strings.Contains(token, "synthetic-key") {
		t.Fatal("secret disclosed")
	}
}
