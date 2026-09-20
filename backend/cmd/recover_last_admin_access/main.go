package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"

	"voice-platform/backend/internal/cli/password_input"
	"voice-platform/backend/internal/database/pool"
	"voice-platform/backend/internal/identity/recover_last_administrator_access"
	recoverpostgres "voice-platform/backend/internal/identity/recover_last_administrator_access/postgres"
)

func main() {
	login := flag.String("login", "", "sole active administrator login to recover")
	passwordStdin := flag.Bool("password-stdin", false, "read the replacement password from standard input")
	confirmed := flag.Bool("confirm-sole-active-administrator-access-recovery", false, "confirm recovery of the sole active administrator")
	flag.Parse()
	if *login == "" || !*passwordStdin || !*confirmed {
		fmt.Fprintln(os.Stderr, "usage: recover-last-admin-access --login <login> --password-stdin --confirm-sole-active-administrator-access-recovery")
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

	service := recoverlastadministratoraccess.New(recoverpostgres.New(recoverpostgres.NewPoolDatabase(database)))
	err = service.Recover(context.Background(), recoverlastadministratoraccess.Input{Login: *login, Password: password})
	if errors.Is(err, recoverlastadministratoraccess.ErrRecoveryUnavailable) {
		fmt.Fprintln(os.Stderr, "sole active administrator access recovery is unavailable")
		os.Exit(1)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not recover sole active administrator access")
		os.Exit(1)
	}
	fmt.Println("Sole active administrator access recovered; prior sessions were revoked and the event was audited.")
}
