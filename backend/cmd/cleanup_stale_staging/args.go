package main

import (
	"errors"
	"flag"
	"io"
)

func parseArgs(args []string) (bool, int, error) {
	f := flag.NewFlagSet("cleanup-stale-staging", flag.ContinueOnError)
	f.SetOutput(io.Discard)
	dry := f.Bool("dry-run", false, "inspect without mutations")
	limit := f.Int("limit", 100, "maximum files removed per run")
	if err := f.Parse(args); err != nil {
		return false, 0, err
	}
	if f.NArg() != 0 || *limit < 1 || *limit > 100 {
		return false, 0, errors.New("invalid staging cleanup arguments")
	}
	return *dry, *limit, nil
}
