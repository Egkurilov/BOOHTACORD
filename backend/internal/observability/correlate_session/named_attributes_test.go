package correlatesession

import (
	"crypto/sha256"
	"testing"
)

func TestProfileNameDoesNotChangeStableIdentity(t *testing.T) {
	digest := sha256.Sum256([]byte("private-token"))
	before := NamedAttributes("account-1", digest, "Аня [QA]")
	after := NamedAttributes("account-1", digest, "Новое имя")
	if len(before) != 4 || before[0] != after[0] || before[1] != after[1] {
		t.Fatal("renaming must preserve account and session identity")
	}
	if before[2].Key != "user.name" || before[2].Value.AsString() != "Аня [QA]" || before[3].Value.AsString() != "Аня [QA] · account-1" {
		t.Fatal("profile name or readable label missing")
	}
	if before[3] == NamedAttributes("account-2", digest, "Аня [QA]")[3] {
		t.Fatal("duplicate display names must retain different labels")
	}
	if len(NamedAttributes("", digest, "unverified")) != 0 || len(NamedAttributes("account-1", digest, "")) != 2 {
		t.Fatal("missing names must not invent a profile")
	}
}
