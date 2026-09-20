package main

import (
	"context"
	"errors"
	"fmt"
	"os"

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
	database, err := pool.Open(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open database")
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
