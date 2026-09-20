//go:build linux

package reserveuploadspace

import (
	"context"
	"fmt"
	"syscall"
)

const maximumInt64 = int64(1<<63 - 1)

type Filesystem struct{ path string }

func NewFilesystem(path string) (Filesystem, error) {
	if path == "" {
		return Filesystem{}, ErrInvalidSpace
	}
	return Filesystem{path: path}, nil
}

func (filesystem Filesystem) Snapshot(ctx context.Context) (Snapshot, error) {
	if err := ctx.Err(); err != nil {
		return Snapshot{}, err
	}
	var stats syscall.Statfs_t
	if err := syscall.Statfs(filesystem.path, &stats); err != nil {
		return Snapshot{}, fmt.Errorf("stat attachment filesystem: %w", err)
	}
	available, err := bytesForBlocks(stats.Bavail, stats.Bsize)
	if err != nil {
		return Snapshot{}, err
	}
	total, err := bytesForBlocks(stats.Blocks, stats.Bsize)
	if err != nil || available > total {
		return Snapshot{}, ErrInvalidSpace
	}
	return Snapshot{AvailableBytes: available, TotalBytes: total}, nil
}

func bytesForBlocks(blocks uint64, blockSize int64) (int64, error) {
	if blockSize <= 0 || blocks > uint64(maximumInt64)/uint64(blockSize) {
		return 0, ErrInvalidSpace
	}
	return int64(blocks) * blockSize, nil
}
