package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	app "voice-platform/backend/internal/app/runtime"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := app.Run(ctx); err != nil {
		slog.Error("api stopped", "error", err)
		os.Exit(1)
	}
}
