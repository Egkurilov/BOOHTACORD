package inspectreadiness

import (
	"context"
	"time"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
)

type Database interface {
	Inspect(context.Context) (int64, error)
}
type SFU interface{ Ping(context.Context) error }
type Probe struct {
	Status             string     `json:"status"`
	Reason             string     `json:"reason,omitempty"`
	SampledAt          *time.Time `json:"sampled_at"`
	PendingRevocations *int64     `json:"pending_revocations"`
	AvailableBytes     *int64     `json:"available_bytes"`
	TotalBytes         *int64     `json:"total_bytes"`
	ReservedBytes      *int64     `json:"reserved_bytes"`
	ProtectedBytes     *int64     `json:"protected_bytes"`
	HeadroomBytes      *int64     `json:"headroom_bytes"`
}
type Result struct {
	Status    string    `json:"status"`
	CheckedAt time.Time `json:"checked_at"`
	Database  Probe     `json:"database"`
	SFU       Probe     `json:"sfu"`
	Storage   Probe     `json:"storage"`
}
type Service struct {
	database                              Database
	sfu                                   SFU
	space                                 reserve.Space
	reserved                              func() int64
	databaseProbe, sfuProbe, storageProbe boundedProbe
}

func New(database Database, sfu SFU, space reserve.Space, reserved func() int64) *Service {
	return &Service{database: database, sfu: sfu, space: space, reserved: reserved}
}
