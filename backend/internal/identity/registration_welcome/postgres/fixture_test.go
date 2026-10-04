package welcomepostgres

import (
	"context"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"strings"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type fakeDatabase struct{ tx *fakeTransaction }

func (d fakeDatabase) Begin(context.Context) (pgx.Tx, error) { return d.tx, nil }

type fakeTransaction struct {
	pgx.Tx
	channel                       *string
	active, committed, rolledBack bool
	welcomeCount                  int
	insertError                   error
	statements                    []string
}

func (tx *fakeTransaction) Exec(_ context.Context, sql string, _ ...any) (pgconn.CommandTag, error) {
	tx.statements = append(tx.statements, sql)
	if strings.Contains(sql, "INSERT INTO messages") {
		tx.welcomeCount++
		if tx.insertError != nil {
			return pgconn.CommandTag{}, tx.insertError
		}
	}
	return pgconn.NewCommandTag("INSERT 0 1"), nil
}
func (tx *fakeTransaction) QueryRow(_ context.Context, sql string, _ ...any) pgx.Row {
	if strings.Contains(sql, "welcome_channel_id") {
		return rowFunc(func(dest ...any) error { *(dest[0].(**string)) = tx.channel; return nil })
	}
	return rowFunc(func(dest ...any) error { *(dest[0].(*bool)) = tx.active; return nil })
}
func (tx *fakeTransaction) Commit(context.Context) error { tx.committed = true; return nil }
func (tx *fakeTransaction) Rollback(context.Context) error {
	if !tx.committed {
		tx.rolledBack = true
	}
	return nil
}

type rowFunc func(...any) error

func (r rowFunc) Scan(dest ...any) error { return r(dest...) }

type publisher struct {
	calls int
	err   error
	event eventhub.Event
}

func (p *publisher) PublishContext(_ context.Context, event eventhub.Event) error {
	p.calls++
	p.event = event
	return p.err
}

type counters struct{ welcome string }

func (c *counters) RegistrationWelcome(outcome string) { c.welcome = outcome }
func (*counters) GuildSettingsUpdate(string)           {}
