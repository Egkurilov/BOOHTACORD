package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"

	"voice-platform/backend/internal/cli/password_input"
	"voice-platform/backend/internal/database/pool"
	"voice-platform/backend/internal/identity/recover_administrator"
	recoverpostgres "voice-platform/backend/internal/identity/recover_administrator/postgres"
)

func main() {
	login := flag.String("login", "", "existing account login to recover")
	passwordStdin := flag.Bool("password-stdin", false, "read the replacement password from standard input")
	flag.Parse()
	if *login == "" || !*passwordStdin {
		fmt.Fprintln(os.Stderr, "usage: recover-admin --login <login> --password-stdin")
		os.Exit(2)
	}
	password, err := passwordinput.Read(os.Stdin)
	if err != nil {
		fmt.Fprintln(os.Stderr, "password input is invalid")
		os.Exit(2)
	}

	database, err := pool.Open(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not open database")
		os.Exit(1)
	}
	defer database.Close()

	service := recoveradministrator.New(recoverpostgres.New(recoverpostgres.NewPoolDatabase(database)))
	err = service.Recover(context.Background(), recoveradministrator.Input{Login: *login, Password: password})
	if errors.Is(err, recoveradministrator.ErrRecoveryUnavailable) {
		fmt.Fprintln(os.Stderr, "administrator recovery is unavailable")
		os.Exit(1)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not recover administrator")
		os.Exit(1)
	}
	fmt.Println("Administrator recovery completed; prior sessions were revoked and the event was audited.")
}
