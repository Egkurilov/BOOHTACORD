package createtextmessagepostgres

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
)

// Test-process entrypoint: exit after the real domain commit, before journal append.
func TestPostCommitCrashWorker(t *testing.T) {
	if os.Getenv("JOURNAL_FAULT_WORKER") != "1" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	config, err := pgxpool.ParseConfig(os.Getenv("JOURNAL_FAULT_DSN"))
	if err != nil {
		t.Fatal("invalid isolated database config")
	}
	config.ConnConfig.RuntimeParams["search_path"] = os.Getenv("JOURNAL_FAULT_SCHEMA")
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal("isolated database unavailable")
	}
	service := createtextmessage.New(New(NewPoolDatabase(pool)))
	_, err = service.Create(ctx, createtextmessage.Input{
		ActorID: os.Getenv("JOURNAL_FAULT_ACTOR"), ChannelID: os.Getenv("JOURNAL_FAULT_CHANNEL"),
		ClientMessageID: os.Getenv("JOURNAL_FAULT_CLIENT"), Body: "synthetic crash fixture",
	})
	if err != nil {
		t.Fatal("domain write failed before crash injection")
	}
	os.Exit(73)
}
