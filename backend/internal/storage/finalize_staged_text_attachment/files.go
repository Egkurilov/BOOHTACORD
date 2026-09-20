package finalizestagedtextattachment

import (
	"errors"
	"fmt"
	"os"
)

var (
	ErrInvalidStorageDirectories = errors.New("invalid attachment storage directories")
	ErrInvalidTemporaryPath      = errors.New("invalid staged attachment path")
	ErrInvalidStorageKey         = errors.New("invalid attachment storage key")
	ErrStorageKeyExists          = errors.New("attachment storage key already exists")
)

type FileStore struct{ stagingDirectory, unattachedDirectory string }

func NewFileStore(stagingDirectory, unattachedDirectory string) (FileStore, error) {
	staging, err := existingDirectory(stagingDirectory)
	if err != nil {
		return FileStore{}, ErrInvalidStorageDirectories
	}
	unattached, err := existingDirectory(unattachedDirectory)
	if err != nil || staging == unattached {
		return FileStore{}, ErrInvalidStorageDirectories
	}
	return FileStore{stagingDirectory: staging, unattachedDirectory: unattached}, nil
}

func (store FileStore) Move(tempPath, key string) error {
	source, err := store.stagedPath(tempPath)
	if err != nil {
		return err
	}
	destination, err := store.storagePath(key)
	if err != nil {
		return err
	}
	if _, err := os.Lstat(destination); err == nil {
		return ErrStorageKeyExists
	} else if !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("inspect private attachment destination: %w", err)
	}
	if err := os.Rename(source, destination); err != nil {
		return fmt.Errorf("atomically move staged attachment: %w", err)
	}
	return nil
}

func (store FileStore) Remove(key string) error {
	path, err := store.storagePath(key)
	if err != nil {
		return err
	}
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove private unattached attachment: %w", err)
	}
	return nil
}
