package senddirectmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMTenAttachmentsCommitAndEleventhRejectsAtomicallyInPostgres(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	ids := []string{f.attachment}
	for len(ids) < 11 {
		id := uuid.NewString()
		_, err := f.pool.Exec(ctx, `INSERT INTO attachments (id,owner_id,direct_message_id,original_name,storage_key,byte_size,state) VALUES ($1,$2,$3,'fixture.bin',$4,1,'UNATTACHED')`, id, f.actor, f.pair, uuid.NewString())
		if err != nil {
			t.Fatal(err)
		}
		ids = append(ids, id)
	}
	sender := send.New(New(NewPoolDatabase(f.pool)))
	message, err := sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "batch", AttachmentIDs: ids[:10]})
	if err != nil {
		t.Fatal(err)
	}
	var linked int
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM direct_message_attachments WHERE message_id=$1`, message.ID).Scan(&linked); err != nil || linked != 10 {
		t.Fatalf("linked=%d err=%v", linked, err)
	}
	var untouched string
	if err := f.pool.QueryRow(ctx, `SELECT state FROM attachments WHERE id=$1`, ids[10]).Scan(&untouched); err != nil || untouched != "UNATTACHED" {
		t.Fatalf("eleventh state=%s err=%v", untouched, err)
	}
	clientID := uuid.NewString()
	_, err = sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: clientID, Body: "too many", AttachmentIDs: ids})
	if !errors.Is(err, send.ErrInvalidInput) {
		t.Fatalf("eleven-attachment error=%v", err)
	}
	assertDMMessageCount(t, f, clientID, 0)
}
