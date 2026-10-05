package revokesessions

import (
	"crypto/sha256"
	"errors"
)

var ErrNotFound = errors.New("owned active session not found")
var ErrUnauthenticated = errors.New("initiating session is no longer active")

type Input struct {
	AccountID string
	Current   [sha256.Size]byte
	SessionID string
	Others    bool
}
type Result struct {
	CurrentRevoked bool
	Count          int
}
