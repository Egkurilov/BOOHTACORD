package rolepolicypostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestLoadMemberReadsAllFlagsAndRevision(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{true, false, true, true, false, true, int64(9)}}}
	policy, err := New(database).LoadMember(context.Background())
	if err != nil || !policy.TextCreate || policy.TextDelete || !policy.VoiceCreate || !policy.VoiceDelete || policy.CategoryCreate || !policy.CategoryDelete || policy.Revision != 9 {
		t.Fatalf("LoadMember() = %#v, %v", policy, err)
	}
	if !strings.Contains(database.statement, "FROM role_permissions") || database.arguments[0] != "MEMBER" {
		t.Fatalf("query = %q, args = %#v", database.statement, database.arguments)
	}
}

func TestLoadMemberRejectsMissingOrInvalidPolicy(t *testing.T) {
	for _, row := range []Row{fakeRow{err: errors.New("missing")}, fakeRow{values: []any{true, false, true, false, true, false, int64(0)}}} {
		if _, err := New(&fakeDatabase{row: row}).LoadMember(context.Background()); err == nil {
			t.Fatal("LoadMember() error = nil")
		}
	}
}

type fakeDatabase struct {
	row       Row
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement, database.arguments = statement, arguments
	return database.row
}

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	return nil, errors.New("unused")
}

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	for index, value := range row.values {
		switch destination := destinations[index].(type) {
		case *bool:
			*destination = value.(bool)
		case *int64:
			*destination = value.(int64)
		}
	}
	return nil
}
