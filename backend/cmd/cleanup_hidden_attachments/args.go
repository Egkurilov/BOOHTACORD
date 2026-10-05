package main

import (
	"flag"
	"io"
	cleanup "voice-platform/backend/internal/storage/cleanup_hidden_attachments"
)

type mode struct {
	limit  int
	dryRun bool
}

func parseMode(args []string) (mode, error) {
	flags := flag.NewFlagSet("cleanup-hidden-attachments", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	limit := flags.Int("limit", cleanup.MaxBatch, "maximum rows per run")
	dryRun := flags.Bool("dry-run", false, "inspect without database/filesystem mutations")
	if err := flags.Parse(args); err != nil {
		return mode{}, err
	}
	if flags.NArg() != 0 || *limit < 1 || *limit > cleanup.MaxBatch {
		return mode{}, cleanup.ErrInvalidRun
	}
	return mode{limit: *limit, dryRun: *dryRun}, nil
}
func parseArgs(args []string) (int, error) { mode, err := parseMode(args); return mode.limit, err }
