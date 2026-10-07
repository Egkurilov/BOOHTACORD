package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"
	"voice-platform/backend/internal/load/run_profile"
	"voice-platform/backend/internal/load/validate_target"
)

func main() {
	profile := flag.String("profile", "normal", "normal, reconnect, uploads or faults")
	flag.Parse()
	var manifest validate_target.Manifest
	decoder := json.NewDecoder(io.LimitReader(os.Stdin, 1<<20))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&manifest) != nil {
		fmt.Fprintln(os.Stderr, "invalid private fixture input")
		os.Exit(2)
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	runner := run_profile.Runner{Manifest: manifest, Profile: *profile}
	report := runner.Run(ctx)
	json.NewEncoder(os.Stdout).Encode(report)
	if report.Outcome != "PASS" || report.Cleanup != "PASS" {
		os.Exit(1)
	}
}
