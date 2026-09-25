package searchmessagespostgres

import (
	"context"
	"sort"
	"testing"
	"time"

	"github.com/google/uuid"
)

type searchRows struct {
	channelNewest string
	channelOlder  string
	dmNewest      string
	russian       string
	phrase        string
}

func seedSearchRows(t *testing.T, fixture searchFixture) searchRows {
	t.Helper()
	ctx := context.Background()
	insert := func(statement string, args ...any) {
		t.Helper()
		if _, err := fixture.pool.Exec(ctx, statement, args...); err != nil {
			t.Fatal("seed search row:", err)
		}
	}
	insert("INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'reader', 'Reader', 'test-only', 'MEMBER')", fixture.actorID)
	insert("INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'irina', 'Ирина', 'test-only', 'MEMBER')", fixture.peerID)
	insert("INSERT INTO users (id, login, display_name, password_hash, role) VALUES ($1, 'admin', 'Admin', 'test-only', 'ADMINISTRATOR')", fixture.adminID)
	categoryID := uuid.NewString()
	insert("INSERT INTO categories (id, name, position) VALUES ($1, 'General', 0)", categoryID)
	insert("INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'Text', 'TEXT', 0)", fixture.channelID, categoryID)
	participants := []string{fixture.actorID, fixture.peerID}
	sort.Strings(participants)
	insert("INSERT INTO direct_messages (id, participant_one_id, participant_two_id) VALUES ($1, $2, $3)", fixture.dmID, participants[0], participants[1])
	base := time.Date(2026, 9, 25, 0, 0, 0, 0, time.UTC)
	rows := searchRows{channelNewest: "33333333-3333-4333-8333-333333333333", channelOlder: uuid.NewString(), dmNewest: "44444444-4444-4444-8444-444444444444", russian: uuid.NewString(), phrase: uuid.NewString()}
	insert("INSERT INTO messages (id, channel_id, author_id, client_message_id, body, created_at) VALUES ($1,$2,$3,$4,$5,$6)", rows.channelOlder, fixture.channelID, fixture.actorID, uuid.NewString(), "orbit first", base.Add(time.Minute))
	insert("INSERT INTO messages (id, channel_id, author_id, client_message_id, body, created_at) VALUES ($1,$2,$3,$4,$5,$6)", rows.channelNewest, fixture.channelID, fixture.actorID, uuid.NewString(), "orbit second", base.Add(5*time.Minute))
	insert("INSERT INTO direct_message_messages (id, direct_message_id, author_id, client_message_id, body, created_at) VALUES ($1,$2,$3,$4,$5,$6)", rows.dmNewest, fixture.dmID, fixture.peerID, uuid.NewString(), "orbit private", base.Add(5*time.Minute))
	insert("INSERT INTO messages (id, channel_id, author_id, client_message_id, body, created_at) VALUES ($1,$2,$3,$4,$5,$6)", rows.russian, fixture.channelID, fixture.actorID, uuid.NewString(), "Ирина сказала привет", base.Add(6*time.Minute))
	insert("INSERT INTO messages (id, channel_id, author_id, client_message_id, body, created_at) VALUES ($1,$2,$3,$4,$5,$6)", rows.phrase, fixture.channelID, fixture.actorID, uuid.NewString(), "точная фраза сегодня", base.Add(7*time.Minute))
	insert("INSERT INTO messages (id, channel_id, author_id, client_message_id, body, created_at) VALUES ($1,$2,$3,$4,$5,$6)", uuid.NewString(), fixture.channelID, fixture.peerID, uuid.NewString(), "точная важная фраза", base.Add(8*time.Minute))
	insert("INSERT INTO messages (id, channel_id, author_id, client_message_id, body, created_at) VALUES ($1,$2,$3,$4,$5,$6)", uuid.NewString(), fixture.channelID, fixture.peerID, uuid.NewString(), "обновление", base.Add(9*time.Minute))
	return rows
}
