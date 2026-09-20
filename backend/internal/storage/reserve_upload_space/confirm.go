package reserveuploadspace

import "context"

func (manager *Manager) Confirm(ctx context.Context) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	manager.mu.Lock()
	defer manager.mu.Unlock()
	snapshot, err := manager.space.Snapshot(ctx)
	if err != nil {
		return err
	}
	minimum, err := protectedBytes(snapshot)
	if err != nil {
		return err
	}
	if snapshot.AvailableBytes < minimum || manager.reserved > snapshot.AvailableBytes-minimum {
		return ErrInsufficientStorage
	}
	return nil
}
