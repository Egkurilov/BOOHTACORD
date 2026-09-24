package resolvedirectmessagerecipientspostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
)

const (
	directMessageID = "11111111-1111-4111-8111-111111111111"
	participantOne  = "22222222-2222-4222-8222-222222222222"
	participantTwo  = "33333333-3333-4333-8333-333333333333"
	administrator   = "44444444-4444-4444-8444-444444444444"
)

type fakeRow struct {
	first, second             string
	firstActive, secondActive bool
	err                       error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	*destinations[0].(*string) = row.first
	*destinations[1].(*string) = row.second
	*destinations[2].(*bool) = row.firstActive
	*destinations[3].(*bool) = row.secondActive
	return nil
}

type fakeDatabase struct {
	row   fakeRow
	query string
	args  []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, query string, args ...any) Row {
	database.query, database.args = query, args
	return database.row
}

func TestResolveReturnsOnlyCurrentActivePairMembers(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{first: participantOne, second: participantTwo, firstActive: true, secondActive: true}}
	recipients, err := New(database).Resolve(context.Background(), directMessageID, participantOne)
	if err != nil || len(recipients) != 2 || recipients[0] != participantOne || recipients[1] != participantTwo {
		t.Fatalf("recipients=%v err=%v", recipients, err)
	}
	if len(database.args) != 2 || database.args[0] != directMessageID || database.args[1] != participantOne {
		t.Fatalf("query args = %#v", database.args)
	}
	for _, predicate := range []string{"$2::uuid IN (dm.participant_one_id, dm.participant_two_id)", "actor.blocked_at IS NULL", "first_user.blocked_at IS NULL", "second_user.blocked_at IS NULL"} {
		if !strings.Contains(database.query, predicate) {
			t.Fatalf("query misses current ACL predicate %q", predicate)
		}
	}
}

func TestResolveOmitsBlockedRecipient(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{first: participantOne, second: participantTwo, firstActive: true, secondActive: false}}
	recipients, err := New(database).Resolve(context.Background(), directMessageID, participantOne)
	if err != nil || len(recipients) != 1 || recipients[0] != participantOne {
		t.Fatalf("recipients=%v err=%v", recipients, err)
	}
}

func TestResolveDeniesNonparticipantAndBlockedActor(t *testing.T) {
	for _, actor := range []string{administrator, participantOne} {
		database := &fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}
		recipients, err := New(database).Resolve(context.Background(), directMessageID, actor)
		if err != nil || len(recipients) != 0 {
			t.Fatalf("actor=%s recipients=%v err=%v", actor, recipients, err)
		}
	}
}

func TestResolvePreservesDatabaseFailure(t *testing.T) {
	failure := errors.New("db failed")
	database := &fakeDatabase{row: fakeRow{err: failure}}
	recipients, err := New(database).Resolve(context.Background(), directMessageID, participantOne)
	if recipients != nil || !errors.Is(err, failure) {
		t.Fatalf("recipients=%v err=%v", recipients, err)
	}
}
