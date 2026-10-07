package screenpreview

import (
	"context"
	"errors"
	"time"
)

const (
	SchemaVersion  = 1
	PreviewTTL     = 15 * time.Second
	UploadInterval = 4 * time.Second
)

var (
	ErrInvalidInput    = errors.New("invalid screen preview request")
	ErrDenied          = errors.New("screen preview access denied")
	ErrUnavailable     = errors.New("screen preview unavailable")
	ErrNoPublication   = errors.New("current screen publication not found")
	ErrNotFound        = errors.New("screen preview not found")
	ErrNoUpdate        = errors.New("screen preview has no newer revision")
	ErrRateLimited     = errors.New("screen preview rate limited")
	ErrCapacity        = errors.New("screen preview capacity reached")
	ErrStaleGeneration = errors.New("screen preview generation superseded")
)

type Principal struct {
	AccountID     string
	SessionDigest [32]byte
}
type Authority interface {
	AuthorizeUploader(context.Context, Principal, string) (string, error)
	AuthorizeViewer(context.Context, Principal, string) (string, error)
}
type PublicationVerifier interface {
	CurrentTrack(context.Context, string, string) (string, error)
}
type Store interface {
	Begin(string, string) (string, error)
	Track(string, string) (string, error)
	Reserve(string, string, uint64) (string, error)
	Commit(string, string, uint64, []byte) error
	Read(string, string) ([]byte, uint64, bool, error)
	Invalidate(string, string) error
}
type HintPublisher interface {
	Updated(context.Context, string, string, uint64)
	Invalidated(context.Context, string, string)
}
type Service struct {
	authority    Authority
	publications PublicationVerifier
	store        Store
	hints        HintPublisher
}
type Generation struct {
	SchemaVersion          int    `json:"schema_version"`
	GenerationID           string `json:"generation_id"`
	ExpiresAfterSeconds    int    `json:"expires_after_seconds"`
	MinimumIntervalSeconds int    `json:"minimum_interval_seconds"`
}
type Preview struct {
	JPEG     []byte
	Revision uint64
}
