package writerlock

import (
	"errors"
	"os"
	"path/filepath"
	"sync"
)

var ErrBusy = errors.New("attachment volume already has an API writer")

type Lock struct {
	file *os.File
	once sync.Once
	err  error
}

func Acquire(root string) (*Lock, error) {
	if root == "" {
		return nil, errors.New("attachment directory is required")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(filepath.Join(root, ".api-writer.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := acquire(file); err != nil {
		file.Close()
		return nil, err
	}
	return &Lock{file: file}, nil
}

func (lock *Lock) Close() error {
	lock.once.Do(func() { lock.err = errors.Join(release(lock.file), lock.file.Close()) })
	// Never unlink: replacing the inode would permit a second simultaneous owner.
	return lock.err
}
