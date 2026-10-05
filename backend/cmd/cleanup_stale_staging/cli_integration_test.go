package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
	inspect "voice-platform/backend/internal/storage/inspect_attachment_cleanup"
)

func TestActualStagingCLIDryRunPreservesFile(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "staging")
	if err := os.Mkdir(dir, 0700); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "upload-private.part")
	if err := os.WriteFile(path, []byte("synthetic"), 0600); err != nil {
		t.Fatal(err)
	}
	old := time.Now().Add(-2 * time.Hour)
	if err := os.Chtimes(path, old, old); err != nil {
		t.Fatal(err)
	}
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	command := exec.Command(executable, "-test.run=^TestStagingCLIHelper$")
	command.Env = append(os.Environ(), "QA_CLEANUP_HELPER=1", "ATTACHMENTS_DIRECTORY="+root)
	bytes, err := command.Output()
	if err != nil {
		t.Fatal("actual CLI failed", err)
	}
	var report inspect.Report
	if err := json.Unmarshal(bytes, &report); err != nil {
		t.Fatal(err)
	}
	if report.Eligible.Count != 1 || report.Eligible.Bytes != 9 {
		t.Fatal("wrong dry-run report")
	}
	if data, err := os.ReadFile(path); err != nil || string(data) != "synthetic" {
		t.Fatal("dry-run removed or changed file")
	}
}

func TestStagingCLIHelper(t *testing.T) {
	if os.Getenv("QA_CLEANUP_HELPER") != "1" {
		return
	}
	os.Args = []string{"cleanup-stale-staging", "--dry-run", "--limit=1"}
	main()
	os.Exit(0)
}

func TestStagingArgsRejectUnboundedAndUnknownOptions(t *testing.T) {
	for _, args := range [][]string{{"--limit=0"}, {"--limit=101"}, {"--unknown"}, {"extra"}} {
		if _, _, err := parseArgs(args); err == nil {
			t.Fatal("unsafe arguments accepted")
		}
	}
}
