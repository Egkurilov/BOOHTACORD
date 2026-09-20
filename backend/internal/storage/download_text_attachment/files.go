package downloadtextattachment

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

var (
	ErrInvalidStorageDirectory = errors.New("invalid private attachment directory")
	ErrInvalidStorageKey       = errors.New("invalid private attachment storage key")
)

type FileStore struct{ directory string }

func NewFileStore(directory string) (FileStore, error) {
	resolved, err := filepath.EvalSymlinks(directory)
	if err != nil {
		return FileStore{}, ErrInvalidStorageDirectory
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.IsDir() {
		return FileStore{}, ErrInvalidStorageDirectory
	}
	return FileStore{directory: resolved}, nil
}

func (store FileStore) Open(key string, expectedSize int64) (io.ReadCloser, error) {
	if expectedSize < 0 || expectedSize > MaxAttachmentBytes {
		return nil, ErrFileUnavailable
	}
	path, err := store.storagePath(key)
	if err != nil {
		return nil, err
	}
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) || err == nil && (!info.Mode().IsRegular() || info.Size() != expectedSize) {
		return nil, ErrFileUnavailable
	}
	if err != nil {
		return nil, fmt.Errorf("inspect private attachment: %w", err)
	}
	file, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, ErrFileUnavailable
	}
	if err != nil {
		return nil, fmt.Errorf("open private attachment: %w", err)
	}
	opened, err := file.Stat()
	if err != nil || !opened.Mode().IsRegular() || opened.Size() != expectedSize {
		_ = file.Close()
		return nil, ErrFileUnavailable
	}
	return file, nil
}

func (store FileStore) storagePath(key string) (string, error) {
	if !validUUID(key) {
		return "", ErrInvalidStorageKey
	}
	return filepath.Join(store.directory, key), nil
}
