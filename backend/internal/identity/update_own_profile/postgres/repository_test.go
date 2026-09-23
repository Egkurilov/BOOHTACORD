package updateprofilepostgres

import (
	"context"
	"strings"
	"testing"

	updateownprofile "voice-platform/backend/internal/identity/update_own_profile"
)

func TestRepositoryUpdatesOnlyDisplayNameForTheOwnedAccount(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"account-1", "immutable", "Новое имя", "MEMBER", true}}}
	profile, err := New(database).Update(context.Background(), updateownprofile.Input{AccountID: "account-1", DisplayName: "Новое имя"})
	if err != nil || profile != (updateownprofile.Profile{AccountID: "account-1", Login: "immutable", DisplayName: "Новое имя", Role: "MEMBER", HasAvatar: true}) {
		t.Fatalf("Update() = %#v, %v", profile, err)
	}
	if !strings.Contains(database.statement, "SET display_name = $2") || strings.Contains(strings.ToLower(database.statement), "role =") || strings.Contains(strings.ToLower(database.statement), "login =") || database.arguments[0] != "account-1" || database.arguments[1] != "Новое имя" {
		t.Fatalf("unsafe profile update: statement=%s args=%#v", database.statement, database.arguments)
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement = statement
	database.arguments = arguments
	return database.row
}

type fakeRow struct{ values []any }

func (row fakeRow) Scan(destinations ...any) error {
	for index, value := range row.values {
		switch destination := destinations[index].(type) {
		case *string:
			*destination = value.(string)
		case *bool:
			*destination = value.(bool)
		}
	}
	return nil
}
