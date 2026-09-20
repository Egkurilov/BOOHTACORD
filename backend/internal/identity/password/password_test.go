package password

import (
	"errors"
	"strings"
	"testing"
)

func TestHashAndVerify(t *testing.T) {
	encoded, err := Hash("correct horse battery staple")
	if err != nil {
		t.Fatalf("Hash() error = %v", err)
	}
	if !strings.HasPrefix(encoded, "$argon2id$v=19$m=19456,t=2,p=1$") {
		t.Fatalf("Hash() = %q, want encoded Argon2id parameters", encoded)
	}

	if valid, err := Verify("correct horse battery staple", encoded); err != nil || !valid {
		t.Fatalf("Verify(correct password) = %v, %v; want true, nil", valid, err)
	}
	if valid, err := Verify("wrong password", encoded); err != nil || valid {
		t.Fatalf("Verify(wrong password) = %v, %v; want false, nil", valid, err)
	}
}

func TestHashUsesUniqueSalt(t *testing.T) {
	first, err := Hash("correct horse battery staple")
	if err != nil {
		t.Fatalf("first Hash() error = %v", err)
	}
	second, err := Hash("correct horse battery staple")
	if err != nil {
		t.Fatalf("second Hash() error = %v", err)
	}
	if first == second {
		t.Fatal("Hash() reused a password hash")
	}
}

func TestVerifyRejectsMalformedHash(t *testing.T) {
	valid, err := Verify("correct horse battery staple", "not-an-argon-hash")
	if valid || !errors.Is(err, ErrInvalidHash) {
		t.Fatalf("Verify() = %v, %v; want false, ErrInvalidHash", valid, err)
	}
}
