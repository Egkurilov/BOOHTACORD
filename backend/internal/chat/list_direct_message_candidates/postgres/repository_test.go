package listdirectmessagecandidatespostgres

import (
	"context"
	"strings"
	"testing"

	listdirectmessagecandidates "voice-platform/backend/internal/chat/list_direct_message_candidates"
)

func TestRepositorySelectsOnlyOtherActiveAccountsInStablePages(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{values: [][]any{{candidateB, "Борис"}}}}

	result, err := New(database).List(context.Background(), listdirectmessagecandidates.Request{Input: listdirectmessagecandidates.Input{ActorID: candidateActor, After: candidateA, Limit: 2}})

	if err != nil || len(result) != 1 || database.arguments[0] != candidateActor || database.arguments[1] != candidateA || database.arguments[2] != 2 {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{"id <> $1::uuid", "blocked_at IS NULL", "($2::uuid IS NULL OR id > $2::uuid)", "ORDER BY id ASC", "LIMIT ($3::int + 1)"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in %s", fragment, database.statement)
		}
	}
	if strings.Contains(database.statement, "role") || strings.Contains(database.statement, "login") {
		t.Fatal("candidate projection leaked private fields")
	}
}

const (
	candidateActor = "11111111-1111-4111-8111-111111111111"
	candidateA     = "22222222-2222-4222-8222-222222222222"
	candidateB     = "33333333-3333-4333-8333-333333333333"
)

type fakeDatabase struct {
	rows      *fakeRows
	statement string
	arguments []any
}

func (database *fakeDatabase) Query(_ context.Context, statement string, arguments ...any) (Rows, error) {
	database.statement, database.arguments = statement, arguments
	return database.rows, nil
}

type fakeRows struct {
	values [][]any
	index  int
	err    error
}

func (rows *fakeRows) Next() bool { return rows.index < len(rows.values) }
func (rows *fakeRows) Scan(destinations ...any) error {
	values := rows.values[rows.index]
	rows.index++
	for index, value := range values {
		if destination, ok := destinations[index].(*string); ok {
			*destination = value.(string)
		}
	}
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return rows.err }
