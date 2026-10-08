package main

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

func TestParseModeRequiresExactlyOneExplicitMode(t *testing.T) {
	for _, arguments := range [][]string{nil, {"--enable", "--disable"}, {"--other"}} {
		if _, err := parseMode(arguments); err == nil {
			t.Fatalf("parseMode(%q) accepted an invalid mode", arguments)
		}
	}
	if enable, err := parseMode([]string{"--enable"}); err != nil || !enable {
		t.Fatalf("parseMode(enable) = %v, %v", enable, err)
	}
	if enable, err := parseMode([]string{"--disable"}); err != nil || enable {
		t.Fatalf("parseMode(disable) = %v, %v", enable, err)
	}
}

func TestOpenDatabaseWithRetryRetriesTemporaryConnectionFailures(t *testing.T) {
	attempts := 0
	database, err := openDatabaseWithRetry(
		context.Background(), "postgres://db.example/voice", 5, 0,
		func(_ context.Context, url string) (*pgxpool.Pool, error) {
			attempts++
			if url != "postgres://db.example/voice" {
				t.Fatalf("database URL changed during retry: %q", url)
			}
			if attempts < 3 {
				return nil, errors.New("ping postgres: temporary network failure")
			}
			return nil, nil
		},
	)
	if err != nil || database != nil || attempts != 3 {
		t.Fatalf("database retry = %v, %v, attempts=%d", database, err, attempts)
	}
}

func TestOpenDatabaseWithRetryDoesNotRetryInvalidConfiguration(t *testing.T) {
	attempts := 0
	want := errors.New("open postgres pool: invalid URL")
	_, err := openDatabaseWithRetry(
		context.Background(), "invalid", 5, 0,
		func(context.Context, string) (*pgxpool.Pool, error) {
			attempts++
			return nil, want
		},
	)
	if !errors.Is(err, want) || attempts != 1 {
		t.Fatalf("configuration failure = %v, attempts=%d", err, attempts)
	}
}
