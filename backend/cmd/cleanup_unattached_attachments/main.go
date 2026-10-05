package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"voice-platform/backend/internal/database/pool"
	cleanup "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
	cleanupdb "voice-platform/backend/internal/storage/cleanup_unattached_attachments/postgres"
	inspect "voice-platform/backend/internal/storage/inspect_attachment_cleanup"
)

func main() {
	mode, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "usage: cleanup-unattached-attachments [--dry-run] [--limit=1..100] | --orphan-key=uuid")
		os.Exit(2)
	}
	root := os.Getenv("ATTACHMENTS_DIRECTORY")
	if !filepath.IsAbs(root) {
		fmt.Fprintln(os.Stderr, "absolute ATTACHMENTS_DIRECTORY is required")
		os.Exit(2)
	}
	files, err := cleanup.NewFileStore(filepath.Join(root, "unattached"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open private attachment storage")
		os.Exit(1)
	}
	defer files.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	database, err := pool.Open(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open database")
		os.Exit(1)
	}
	defer database.Close()
	if mode.dryRun {
		report, err := inspect.New(database).Database(ctx, "UNATTACHED", time.Now().UTC())
		if err != nil {
			fmt.Fprintln(os.Stderr, "inspection failed")
			os.Exit(1)
		}
		if err := json.NewEncoder(os.Stdout).Encode(report); err != nil {
			os.Exit(1)
		}
		return
	}
	service := cleanup.New(cleanupdb.New(database), files)
	if mode.orphanKey != "" {
		removed, err := service.RecoverOrphan(ctx, mode.orphanKey, time.Now().UTC())
		if err != nil {
			fmt.Fprintln(os.Stderr, "orphan recovery failed")
			os.Exit(1)
		}
		fmt.Printf("Orphan files removed: %t.\n", removed)
		return
	}
	result, err := service.Run(ctx, time.Now().UTC(), mode.limit)
	fmt.Printf("Claimed: %d; removed: %d; retryable failures: %d.\n", result.Claimed, result.Removed, result.Failed)
	if err != nil {
		if errors.Is(err, cleanup.ErrPartialCleanup) {
			fmt.Fprintln(os.Stderr, "cleanup has retryable failures")
		} else {
			fmt.Fprintln(os.Stderr, "cleanup failed")
		}
		os.Exit(1)
	}
}
