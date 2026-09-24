package cleanupunattachedattachments

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
)

var ErrInvalidDirectory = errors.New("invalid private attachment directory")
var ErrInvalidKey = errors.New("invalid attachment storage key")
var ErrUnsafeFile = errors.New("unsafe private attachment file")

type FileStore struct{ root *os.Root }

func NewFileStore(directory string) (FileStore, error) {
	if !filepath.IsAbs(directory) {
		return FileStore{}, ErrInvalidDirectory
	}
	resolved, err := filepath.EvalSymlinks(directory)
	if err != nil {
		return FileStore{}, ErrInvalidDirectory
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.IsDir() {
		return FileStore{}, ErrInvalidDirectory
	}
	root, err := os.OpenRoot(resolved)
	if err != nil {
		return FileStore{}, fmt.Errorf("open private attachment directory: %w", err)
	}
	return FileStore{root: root}, nil
}

func (store FileStore) Close() error { return store.root.Close() }

func (store FileStore) Remove(key string) error {
	if !validKey(key) {
		return ErrInvalidKey
	}
	info, err := store.root.Lstat(key)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect private attachment: %w", err)
	}
	if !info.Mode().IsRegular() {
		return ErrUnsafeFile
	}
	if err := store.root.Remove(key); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove private attachment: %w", err)
	}
	return nil
}

func (store FileStore) OldRegular(key string, cutoff time.Time) (bool, error) {
	if !validKey(key) {
		return false, ErrInvalidKey
	}
	if cutoff.IsZero() {
		return false, ErrInvalidRun
	}
	info, err := store.root.Lstat(key)
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("inspect orphan attachment: %w", err)
	}
	if !info.Mode().IsRegular() {
		return false, ErrUnsafeFile
	}
	return info.ModTime().Before(cutoff), nil
}

func validKey(key string) bool {
	id, err := uuid.Parse(key)
	return err == nil && id.String() == key
}
