package finalizestagedtextattachment

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

func (store FileStore) stagedPath(tempPath string) (string, error) {
	path, err := filepath.EvalSymlinks(tempPath)
	if err != nil {
		return "", fmt.Errorf("%w: %v", ErrInvalidTemporaryPath, err)
	}
	relative, err := filepath.Rel(store.stagingDirectory, path)
	if err != nil || relative == "." || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return "", ErrInvalidTemporaryPath
	}
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() {
		return "", ErrInvalidTemporaryPath
	}
	return path, nil
}

func (store FileStore) storagePath(key string) (string, error) {
	if !validUUID(key) {
		return "", ErrInvalidStorageKey
	}
	return filepath.Join(store.unattachedDirectory, key), nil
}

func existingDirectory(path string) (string, error) {
	if path == "" {
		return "", ErrInvalidStorageDirectories
	}
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		return "", err
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.IsDir() {
		return "", ErrInvalidStorageDirectories
	}
	return resolved, nil
}

func validUUID(value string) bool {
	_, err := uuid.Parse(value)
	return err == nil && len(value) == 36
}
