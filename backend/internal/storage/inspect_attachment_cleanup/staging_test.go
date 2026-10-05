package inspectattachmentcleanup

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestStagingInspectionHasOnlyAggregateCountsAndDoesNotMutate(t *testing.T) {
	dir := t.TempDir()
	now := time.Now()
	for _, item := range []struct {
		name string
		age  time.Duration
	}{
		{"upload-old.part", 2 * time.Hour}, {"upload-fresh.part", time.Minute}, {"private-name.bin", 2 * time.Hour},
	} {
		path := filepath.Join(dir, item.name)
		if err := os.WriteFile(path, []byte("test"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(path, now.Add(-item.age), now.Add(-item.age)); err != nil {
			t.Fatal(err)
		}
	}
	report, err := Staging(dir, now)
	if err != nil || report.Eligible.Count != 1 || report.Eligible.Bytes != 4 || report.Skipped["fresh"].Count != 1 || report.Skipped["unexpected"].Count != 1 {
		t.Fatal("incorrect dry-run totals", err)
	}
	for _, name := range []string{"upload-old.part", "upload-fresh.part", "private-name.bin"} {
		bytes, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil || string(bytes) != "test" {
			t.Fatal("dry-run changed a file")
		}
	}
}
