// check-test-database is a CI command; it never installs or changes a database.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/jackc/pgx/v5"
	"os"
	"strconv"
	"strings"
	"time"
	"voice-platform/backend/internal/testsupport/databasecheck"
)

func run() error {
	config, err := databasecheck.Config(os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL"), os.Getenv("TEST_DATABASE_URL"))
	if err != nil {
		return err
	}
	policy, err := os.ReadFile("../tools/toolchains.json")
	if err != nil {
		return err
	}
	var versions map[string]string
	if err := json.Unmarshal(policy, &versions); err != nil {
		return err
	}
	major, err := strconv.Atoi(strings.Split(versions["postgres"], ".")[0])
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := pgx.ConnectConfig(ctx, config)
	if err != nil {
		return fmt.Errorf("cannot connect to disposable test database")
	}
	defer conn.Close(context.Background())
	var actual int
	if err := conn.QueryRow(ctx, "SELECT current_setting('server_version_num')::integer").Scan(&actual); err != nil {
		return fmt.Errorf("cannot determine test PostgreSQL version")
	}
	if err := databasecheck.Version(actual, major); err != nil {
		return err
	}
	fmt.Printf("Disposable PostgreSQL %d verified\n", actual)
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
