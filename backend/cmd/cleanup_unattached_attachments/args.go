package main

import (
	"flag"
	"github.com/google/uuid"
	"io"
	cleanup "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

type mode struct {
	limit     int
	orphanKey string
	dryRun    bool
}

func parseArgs(args []string) (mode, error) {
	flags := flag.NewFlagSet("cleanup-unattached-attachments", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	limit := flags.Int("limit", cleanup.MaxBatch, "maximum rows per run")
	orphanKey := flags.String("orphan-key", "", "recover one old file without metadata")
	dryRun := flags.Bool("dry-run", false, "inspect without database/filesystem mutations")
	if err := flags.Parse(args); err != nil {
		return mode{}, err
	}
	if flags.NArg() != 0 || *limit < 1 || *limit > cleanup.MaxBatch {
		return mode{}, cleanup.ErrInvalidRun
	}
	if *orphanKey != "" {
		id, err := uuid.Parse(*orphanKey)
		if err != nil || id.String() != *orphanKey {
			return mode{}, cleanup.ErrInvalidKey
		}
		if *limit != cleanup.MaxBatch || *dryRun {
			return mode{}, cleanup.ErrInvalidRun
		}
	}
	return mode{limit: *limit, orphanKey: *orphanKey, dryRun: *dryRun}, nil
}
