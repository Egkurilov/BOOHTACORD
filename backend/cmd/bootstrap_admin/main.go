package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"

	"voice-platform/backend/internal/cli/password_input"
	"voice-platform/backend/internal/database/pool"
	"voice-platform/backend/internal/identity/bootstrap_administrator"
	bootstrappostgres "voice-platform/backend/internal/identity/bootstrap_administrator/postgres"
)

func main() {
	login := flag.String("login", "", "initial administrator login")
	passwordStdin := flag.Bool("password-stdin", false, "read the initial password from standard input")
	flag.Parse()
	if *login == "" || !*passwordStdin {
		fmt.Fprintln(os.Stderr, "usage: bootstrap-admin --login <login> --password-stdin")
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

	service := bootstrapadministrator.New(bootstrappostgres.New(bootstrappostgres.NewPoolDatabase(database)))
	account, err := service.Bootstrap(context.Background(), bootstrapadministrator.Input{Login: *login, Password: password})
	if errors.Is(err, bootstrapadministrator.ErrAlreadyInitialized) {
		fmt.Println("Bootstrap already initialized; no account was changed.")
		return
	}
	if errors.Is(err, bootstrapadministrator.ErrBootstrapIncomplete) {
		fmt.Fprintln(os.Stderr, "bootstrap state is incomplete; deploy the repair migration before retrying")
		os.Exit(1)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not initialize administrator")
		os.Exit(1)
	}
	fmt.Printf("Initial administrator created for %s.\n", account.Login)
}
