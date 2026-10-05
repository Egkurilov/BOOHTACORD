package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	cleanupstalestagingfiles "voice-platform/backend/internal/storage/cleanup_stale_staging_files"
	inspect "voice-platform/backend/internal/storage/inspect_attachment_cleanup"
)

func main() {
	dry, limit, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "usage: cleanup-stale-staging [--dry-run] [--limit=1..100]")
		os.Exit(2)
	}
	root := os.Getenv("ATTACHMENTS_DIRECTORY")
	if !filepath.IsAbs(root) {
		fmt.Fprintln(os.Stderr, "absolute ATTACHMENTS_DIRECTORY is required")
		os.Exit(2)
	}
	directory := filepath.Join(root, "staging")
	if dry {
		report, err := inspect.Staging(directory, time.Now().UTC())
		if err != nil {
			fmt.Fprintln(os.Stderr, "inspection failed")
			os.Exit(1)
		}
		if err := json.NewEncoder(os.Stdout).Encode(report); err != nil {
			os.Exit(1)
		}
		return
	}
	service, err := cleanupstalestagingfiles.New(directory)
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open staging")
		os.Exit(1)
	}
	removed, err := service.RemoveBeforeLimit(time.Now().UTC().Add(-cleanupstalestagingfiles.StagingRetention), limit)
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not remove stale staging files")
		os.Exit(1)
	}
	fmt.Printf("Removed %d stale staging files.\n", removed)
}
