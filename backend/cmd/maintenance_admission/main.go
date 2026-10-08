package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"voice-platform/backend/internal/database/pool"
	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	maintenancepostgres "voice-platform/backend/internal/maintenance/admission/postgres"
)

func main() {
	enable, err := parseMode(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "usage: maintenance-admission --enable|--disable")
		os.Exit(2)
	}
	openContext, cancelOpen := context.WithTimeout(context.Background(), 30*time.Second)
	database, err := openDatabaseWithRetry(openContext, os.Getenv("DATABASE_URL"), 5, 2*time.Second, pool.Open)
	cancelOpen()
	if err != nil {
		fmt.Fprintf(os.Stderr, "could not open database (%s)\n", databaseOpenErrorClass(err))
		os.Exit(1)
	}
	defer database.Close()
	service := maintenanceadmission.New(maintenancepostgres.New(maintenancepostgres.NewPoolDatabase(database)))
	if err := service.Set(context.Background(), enable); err != nil {
		fmt.Fprintln(os.Stderr, "could not change maintenance admission")
		os.Exit(1)
	}
	if enable {
		fmt.Println("Maintenance admission enabled.")
		return
	}
	fmt.Println("Maintenance admission disabled.")
}

func openDatabaseWithRetry(
	ctx context.Context,
	databaseURL string,
	retries int,
	retryDelay time.Duration,
	open func(context.Context, string) (*pgxpool.Pool, error),
) (*pgxpool.Pool, error) {
	if retries < 0 {
		retries = 0
	}
	for attempt := 0; ; attempt++ {
		database, err := open(ctx, databaseURL)
		if err == nil {
			return database, nil
		}
		if attempt >= retries || ctx.Err() != nil || !strings.HasPrefix(err.Error(), "ping postgres:") {
			return nil, err
		}
		timer := time.NewTimer(retryDelay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil, err
		case <-timer.C:
		}
	}
}

func databaseOpenErrorClass(err error) string {
	switch {
	case errors.Is(err, pool.ErrDatabaseURLRequired):
		return "DATABASE_URL missing"
	case strings.HasPrefix(err.Error(), "open postgres pool:"):
		return "configuration"
	case strings.HasPrefix(err.Error(), "ping postgres:"):
		return "connection"
	default:
		return "unknown"
	}
}

func parseMode(arguments []string) (bool, error) {
	if len(arguments) != 1 {
		return false, errors.New("exactly one maintenance mode is required")
	}
	switch arguments[0] {
	case "--enable":
		return true, nil
	case "--disable":
		return false, nil
	default:
		return false, errors.New("unknown maintenance mode")
	}
}
