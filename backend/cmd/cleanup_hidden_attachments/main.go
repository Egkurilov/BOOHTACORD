package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"voice-platform/backend/internal/database/pool"
	cleanup "voice-platform/backend/internal/storage/cleanup_hidden_attachments"
	cleanupdb "voice-platform/backend/internal/storage/cleanup_hidden_attachments/postgres"
	files "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

func parseArgs(args []string) (int, error) {
	flags := flag.NewFlagSet("cleanup-hidden-attachments", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	limit := flags.Int("limit", cleanup.MaxBatch, "maximum rows per run")
	if err := flags.Parse(args); err != nil {
		return 0, err
	}
	if flags.NArg() != 0 || *limit < 1 || *limit > cleanup.MaxBatch {
		return 0, cleanup.ErrInvalidRun
	}
	return *limit, nil
}

func main() {
	limit, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "usage: cleanup-hidden-attachments [--limit=1..100]")
		os.Exit(2)
	}
	root := os.Getenv("ATTACHMENTS_DIRECTORY")
	if !filepath.IsAbs(root) {
		fmt.Fprintln(os.Stderr, "absolute ATTACHMENTS_DIRECTORY is required")
		os.Exit(2)
	}
	fileStore, err := files.NewFileStore(filepath.Join(root, "unattached"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open private attachment storage")
		os.Exit(1)
	}
	defer fileStore.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	database, err := pool.Open(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open database")
		os.Exit(1)
	}
	defer database.Close()
	result, err := cleanup.New(cleanupdb.New(database), fileStore).Run(ctx, time.Now().UTC(), limit)
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
