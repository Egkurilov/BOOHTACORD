package cleanupstalestagingfiles

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

var (
	ErrInvalidStagingDirectory = errors.New("invalid attachment staging directory")
	ErrInvalidCutoff           = errors.New("invalid attachment cleanup cutoff")
)

type Service struct{ directory string }

func New(directory string) (Service, error) {
	resolved, err := filepath.EvalSymlinks(directory)
	if err != nil {
		return Service{}, ErrInvalidStagingDirectory
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.IsDir() {
		return Service{}, ErrInvalidStagingDirectory
	}
	return Service{directory: resolved}, nil
}

func (service Service) RemoveBefore(cutoff time.Time) (int, error) {
	if cutoff.IsZero() {
		return 0, ErrInvalidCutoff
	}
	entries, err := os.ReadDir(service.directory)
	if err != nil {
		return 0, fmt.Errorf("list attachment staging directory: %w", err)
	}
	removed := 0
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !stagedUploadName(entry.Name()) {
			continue
		}
		info, err := entry.Info()
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return removed, fmt.Errorf("inspect staged attachment: %w", err)
		}
		if !info.Mode().IsRegular() || !info.ModTime().Before(cutoff) {
			continue
		}
		if err := os.Remove(filepath.Join(service.directory, entry.Name())); err != nil {
			if errors.Is(err, os.ErrNotExist) {
				continue
			}
			return removed, fmt.Errorf("remove stale staged attachment: %w", err)
		}
		removed++
	}
	return removed, nil
}

func stagedUploadName(name string) bool {
	return strings.HasPrefix(name, "upload-") && strings.HasSuffix(name, ".part")
}
