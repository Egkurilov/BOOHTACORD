package reserveuploadspace

import (
	"context"
	"errors"
	"sync"
)

const (
	MaxAttachmentBytes int64 = 25_000_000
	MinimumFreeBytes   int64 = 2 * 1024 * 1024 * 1024
)

var (
	ErrInvalidSpace        = errors.New("invalid attachment filesystem")
	ErrInsufficientStorage = errors.New("insufficient attachment storage")
)

type Snapshot struct {
	AvailableBytes int64
	TotalBytes     int64
}

type Space interface {
	Snapshot(context.Context) (Snapshot, error)
}

type Manager struct {
	space    Space
	mu       sync.Mutex
	reserved int64
}

type Reservation struct {
	manager *Manager
	release sync.Once
}

func New(space Space) (*Manager, error) {
	if space == nil {
		return nil, ErrInvalidSpace
	}
	return &Manager{space: space}, nil
}

func (manager *Manager) Reserve(ctx context.Context) (*Reservation, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	manager.mu.Lock()
	defer manager.mu.Unlock()
	snapshot, err := manager.space.Snapshot(ctx)
	if err != nil {
		return nil, err
	}
	minimum, err := protectedBytes(snapshot)
	if err != nil {
		return nil, err
	}
	if snapshot.AvailableBytes < minimum {
		return nil, ErrInsufficientStorage
	}
	usable := snapshot.AvailableBytes - minimum
	if manager.reserved > usable || usable-manager.reserved < MaxAttachmentBytes {
		return nil, ErrInsufficientStorage
	}
	manager.reserved += MaxAttachmentBytes
	return &Reservation{manager: manager}, nil
}

func (manager *Manager) ReservedBytes() int64 {
	manager.mu.Lock()
	defer manager.mu.Unlock()
	return manager.reserved
}

func (reservation *Reservation) Release() {
	if reservation == nil {
		return
	}
	reservation.release.Do(func() {
		reservation.manager.mu.Lock()
		defer reservation.manager.mu.Unlock()
		reservation.manager.reserved -= MaxAttachmentBytes
	})
}

func protectedBytes(snapshot Snapshot) (int64, error) {
	if snapshot.AvailableBytes < 0 || snapshot.TotalBytes < 0 {
		return 0, ErrInvalidSpace
	}
	tenth := snapshot.TotalBytes / 10
	if snapshot.TotalBytes%10 != 0 {
		tenth++
	}
	if tenth > MinimumFreeBytes {
		return tenth, nil
	}
	return MinimumFreeBytes, nil
}
