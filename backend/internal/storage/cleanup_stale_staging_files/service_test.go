package cleanupstalestagingfiles

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestRemoveBeforeDeletesOnlyOldDirectStagingPartFiles(t *testing.T) {
	directory := t.TempDir()
	cutoff := time.Date(2026, time.September, 18, 12, 0, 0, 0, time.UTC)
	oldPart := writeFile(t, directory, "upload-old.part", cutoff.Add(-time.Minute))
	recentPart := writeFile(t, directory, "upload-recent.part", cutoff)
	unexpected := writeFile(t, directory, "important.txt", cutoff.Add(-time.Hour))
	if err := os.Symlink(oldPart, filepath.Join(directory, "upload-link.part")); err == nil {
		defer os.Remove(filepath.Join(directory, "upload-link.part"))
	}

	service, err := New(directory)
	if err != nil {
		t.Fatal(err)
	}
	removed, err := service.RemoveBefore(cutoff)
	if err != nil || removed != 1 {
		t.Fatalf("removed = %d, error = %v", removed, err)
	}
	if _, err := os.Stat(oldPart); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("old part stat error = %v", err)
	}
	for _, path := range []string{recentPart, unexpected} {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("preserved path %q stat error = %v", path, err)
		}
	}
}

func TestNewRejectsMissingDirectoryAndRemoveRejectsZeroCutoff(t *testing.T) {
	if _, err := New(filepath.Join(t.TempDir(), "missing")); !errors.Is(err, ErrInvalidStagingDirectory) {
		t.Fatalf("missing directory error = %v", err)
	}
	service, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.RemoveBefore(time.Time{}); !errors.Is(err, ErrInvalidCutoff) {
		t.Fatalf("zero cutoff error = %v", err)
	}
}

func TestRemoveExpiredDeletesOnlyPartsStrictlyOlderThanOneHour(t *testing.T) {
	root := t.TempDir()
	staging := filepath.Join(root, "staging")
	if err := os.Mkdir(staging, 0o700); err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, time.September, 19, 12, 0, 0, 0, time.UTC)
	oldPart := writeFile(t, staging, "upload-old.part", now.Add(-StagingRetention-time.Nanosecond))
	cutoffPart := writeFile(t, staging, "upload-cutoff.part", now.Add(-StagingRetention))
	unexpected := writeFile(t, staging, "important.txt", now.Add(-2*StagingRetention))

	removed, err := RemoveExpired(root, now)
	if err != nil || removed != 1 {
		t.Fatalf("removed = %d, error = %v", removed, err)
	}
	if _, err := os.Stat(oldPart); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("old part stat error = %v", err)
	}
	for _, path := range []string{cutoffPart, unexpected} {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("preserved path %q stat error = %v", path, err)
		}
	}
}

func TestRemoveExpiredRejectsEmptyAndRelativeAttachmentsDirectory(t *testing.T) {
	now := time.Date(2026, time.September, 19, 12, 0, 0, 0, time.UTC)
	for _, root := range []string{"", "attachments"} {
		if _, err := RemoveExpired(root, now); !errors.Is(err, ErrInvalidAttachmentsDirectory) {
			t.Fatalf("root %q error = %v", root, err)
		}
	}
}

func writeFile(t *testing.T, directory, name string, modified time.Time) string {
	t.Helper()
	path := filepath.Join(directory, name)
	if err := os.WriteFile(path, []byte("private staging bytes"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, modified, modified); err != nil {
		t.Fatal(err)
	}
	return path
}
