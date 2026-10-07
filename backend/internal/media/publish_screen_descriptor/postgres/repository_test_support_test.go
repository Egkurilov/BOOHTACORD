package publishscreendescriptorpostgres

import (
	"context"
	"errors"
	"strings"
	"sync"

	"github.com/jackc/pgx/v5"
	publishdescriptor "voice-platform/backend/internal/media/publish_screen_descriptor"
)

const testAccount = "33333333-3333-4333-8333-333333333333"
const foreignAccount = "44444444-4444-4444-8444-444444444444"
const testLease = "11111111-1111-4111-8111-111111111111"
const testChannel = "22222222-2222-4222-8222-222222222222"

type fakeDatabase struct {
	mu                      sync.Mutex
	revision                int64
	hash                    []byte
	account, channel, lease string
	digest                  []byte
}

func (database *fakeDatabase) Begin(context.Context) (Transaction, error) {
	database.mu.Lock()
	return &fakeTransaction{database: database}, nil
}

type fakeTransaction struct {
	database     *fakeDatabase
	nextRevision int64
	nextHash     []byte
	done         bool
}

func (transaction *fakeTransaction) QueryRow(_ context.Context, query string, arguments ...any) Row {
	if !strings.Contains(query, "FOR UPDATE OF lease") || !strings.Contains(query, "session.revoked_at IS NULL") {
		return fakeRow{err: errors.New("missing active lease lock predicates")}
	}
	if arguments[0] != transaction.database.lease || arguments[1] != transaction.database.account || string(arguments[2].([]byte)) != string(transaction.database.digest) {
		return fakeRow{err: pgx.ErrNoRows}
	}
	return fakeRow{values: []any{transaction.database.account, transaction.database.channel, transaction.database.revision, transaction.database.hash}}
}
func (transaction *fakeTransaction) Exec(_ context.Context, query string, arguments ...any) error {
	if !strings.Contains(query, "screen_profile_operation_revision") || arguments[2] != transaction.database.lease {
		return errors.New("receipt update omitted lease scope")
	}
	transaction.nextRevision, transaction.nextHash = arguments[0].(int64), append([]byte(nil), arguments[1].([]byte)...)
	return nil
}
func (transaction *fakeTransaction) Commit(context.Context) error {
	if transaction.done {
		return nil
	}
	transaction.done = true
	if transaction.nextRevision > 0 {
		transaction.database.revision, transaction.database.hash = transaction.nextRevision, transaction.nextHash
	}
	transaction.database.mu.Unlock()
	return nil
}
func (transaction *fakeTransaction) Rollback(context.Context) error {
	if !transaction.done {
		transaction.done = true
		transaction.database.mu.Unlock()
	}
	return nil
}

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(dest ...any) error {
	if row.err != nil {
		return row.err
	}
	if len(dest) != len(row.values) {
		return errors.New("unexpected scan shape")
	}
	*dest[0].(*string), *dest[1].(*string), *dest[2].(*int64), *dest[3].(*[]byte) = row.values[0].(string), row.values[1].(string), row.values[2].(int64), append([]byte(nil), row.values[3].([]byte)...)
	return nil
}

type fakePublisher struct {
	calls                int
	lease, channel, body string
}

func (publisher *fakePublisher) Publish(_ context.Context, lease, channel, body string) error {
	publisher.calls++
	publisher.lease, publisher.channel, publisher.body = lease, channel, body
	return nil
}

func testDescriptor() publishdescriptor.Descriptor {
	return publishdescriptor.Descriptor{SchemaVersion: 1, Scope: publishdescriptor.Scope{MediaSessionID: "session", PublicationGeneration: 1, OperationRevision: 1},
		Mode: "text", PublisherState: "sharing", ViewerState: "idle", RequestedProfileID: "P1080_30",
		EffectiveProfile: publishdescriptor.EffectiveProfile{Capture: publishdescriptor.Capture{MaxWidth: 1920, MaxHeight: 1080, MaxFPS: 30}, Encoding: publishdescriptor.Encoding{Layers: []publishdescriptor.Layer{{Width: 1920, Height: 1080, MaxFPS: 30, MaxBitrateBPS: 2_000_000, ScaleDownBy: 1, Active: true}}}},
		LayerTopology:    "single-layer", ProfileRevision: 1, ReasonCodes: []string{"user-request"}}
}
