package session

import (
	"encoding/base64"
	"testing"
)

func TestIssueCreatesVerifiableOpaqueToken(t *testing.T) {
	issued, err := Issue()
	if err != nil {
		t.Fatalf("Issue() error = %v", err)
	}

	raw, err := base64.RawURLEncoding.DecodeString(issued.Token)
	if err != nil || len(raw) != tokenBytes {
		t.Fatalf("token is not a %d-byte base64url value: %q", tokenBytes, issued.Token)
	}
	if !Verify(issued.Token, issued.Digest) {
		t.Fatal("Verify() rejected the issued token")
	}
	if Verify(issued.Token+"a", issued.Digest) {
		t.Fatal("Verify() accepted a changed token")
	}
}

func TestDigestRejectsMalformedToken(t *testing.T) {
	if _, err := Digest("not valid base64url!"); err == nil {
		t.Fatal("Digest() accepted malformed token")
	}
}
