package correlatesession

import (
	"crypto/sha256"
	"encoding/hex"
	"testing"
)

func TestCorrelationIsStableAndDoesNotExposeSessionCredential(t *testing.T) {
	digest := sha256.Sum256([]byte("private-session-token"))
	first := Attributes("account-1", digest)
	second := Attributes("account-1", digest)
	if len(first) != 2 || first[0].Key != "user.id" || first[0].Value.AsString() != "account-1" {
		t.Fatal("verified account ID missing")
	}
	id := first[1].Value.AsString()
	if first[1].Key != "session.id" || len(id) != 32 || id != second[1].Value.AsString() {
		t.Fatal("session correlation must be stable and bounded")
	}
	if _, err := hex.DecodeString(id); err != nil {
		t.Fatal("session correlation must be hexadecimal")
	}
	if id == hex.EncodeToString(digest[:16]) {
		t.Fatal("session digest must not be exported")
	}
	other := Attributes("account-1", sha256.Sum256([]byte("other-session-token")))
	if id == other[1].Value.AsString() || id == Attributes("account-2", digest)[1].Value.AsString() {
		t.Fatal("separate accounts and sessions must not be grouped together")
	}
}

func TestMissingIdentityDoesNotCreateSharedAnonymousSession(t *testing.T) {
	if got := Attributes("", [32]byte{}); len(got) != 0 {
		t.Fatal("anonymous requests must remain uncorrelated")
	}
	if got := Attributes("account-1", [32]byte{}); len(got) != 1 || got[0].Key != "user.id" {
		t.Fatal("a missing session digest must not produce a common session ID")
	}
}
