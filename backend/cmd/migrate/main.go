package main

import (
	"context"
	"log/slog"
	"os"

	"voice-platform/backend/internal/database/migrate"
	"voice-platform/backend/internal/database/pool"
)

func main() {
	context := context.Background()
	database, err := pool.Open(context, os.Getenv("DATABASE_URL"))
	if err != nil {
		slog.Error("open database for migration", "error", err)
		os.Exit(1)
	}
	defer database.Close()

	if err := migrate.Run(context, database); err != nil {
		slog.Error("apply migrations", "error", err)
		os.Exit(1)
	}
	slog.Info("migrations applied")
}
