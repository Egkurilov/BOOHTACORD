package main

import (
	"log/slog"
	"os"
)

func configureLogging() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
}

func apiAddress() string {
	if address := os.Getenv("API_ADDR"); address != "" {
		return address
	}
	return ":8080"
}
