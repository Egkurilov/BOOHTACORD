package session

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
)

const (
	CookieName = "vp_session"
	tokenBytes = 32
)

var ErrInvalidToken = errors.New("invalid session token")

type Issued struct {
	Token  string
	Digest [sha256.Size]byte
}

func Issue() (Issued, error) {
	raw := make([]byte, tokenBytes)
	if _, err := io.ReadFull(rand.Reader, raw); err != nil {
		return Issued{}, fmt.Errorf("generate session token: %w", err)
	}

	return Issued{
		Token:  base64.RawURLEncoding.EncodeToString(raw),
		Digest: sha256.Sum256(raw),
	}, nil
}

func Digest(token string) ([sha256.Size]byte, error) {
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil || len(raw) != tokenBytes {
		return [sha256.Size]byte{}, ErrInvalidToken
	}
	return sha256.Sum256(raw), nil
}

func Verify(token string, stored [sha256.Size]byte) bool {
	candidate, err := Digest(token)
	if err != nil {
		return false
	}
	return subtle.ConstantTimeCompare(candidate[:], stored[:]) == 1
}
