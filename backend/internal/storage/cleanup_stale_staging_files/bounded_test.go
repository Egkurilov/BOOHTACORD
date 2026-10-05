package cleanupstalestagingfiles

import (
	"fmt"
	"os"
	"testing"
	"time"
)

func TestLimitedCleanupIsBoundedAndRepeatable(t *testing.T) {
	dir := t.TempDir()
	cutoff := time.Now()
	for i := range 4 {
		writeFile(t, dir, fmt.Sprintf("upload-%d.part", i), cutoff.Add(-time.Hour))
	}
	s, err := New(dir)
	if err != nil {
		t.Fatal(err)
	}
	for range 2 {
		removed, err := s.RemoveBeforeLimit(cutoff, 2)
		if err != nil || removed != 2 {
			t.Fatal("unbounded cleanup", err)
		}
	}
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 0 {
		t.Fatal("repeat cleanup lost candidates")
	}
	if _, err := s.RemoveBeforeLimit(cutoff, 0); err == nil {
		t.Fatal("zero limit accepted")
	}
}
