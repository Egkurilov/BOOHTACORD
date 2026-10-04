package notifyleaserevocation

import (
	"context"
	"github.com/google/uuid"
	"testing"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	kickvoiceparticipant "voice-platform/backend/internal/voice/kick_voice_participant"
	kickpostgres "voice-platform/backend/internal/voice/kick_voice_participant/postgres"
)

func TestAdminKickDeliversOnlyTargetedReason(t *testing.T) {
	pool := newNotificationTestPool(t)
	ctx := context.Background()
	admin, owner, other, category, channel, lease := uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString(), uuid.NewString()
	for _, row := range []struct {
		sql  string
		args []any
	}{
		{"INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'admin','Admin','test','ADMINISTRATOR'),($2,'owner','Owner','test','MEMBER'),($3,'other','Other','test','MEMBER')", []any{admin, owner, other}},
		{"INSERT INTO categories(id,name,position) VALUES($1,'Voice',0)", []any{category}},
		{"INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'Voice','VOICE',0)", []any{channel, category}},
		{"INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)", []any{make([]byte, 32), owner}},
		{"INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES($1,$2,$3,$4)", []any{lease, owner, channel, make([]byte, 32)}},
	} {
		if _, err := pool.Exec(ctx, row.sql, row.args...); err != nil {
			t.Fatal(err)
		}
	}
	kick := kickvoiceparticipant.New(kickpostgres.New(kickpostgres.NewPoolDatabase(pool)))
	result, err := kick.Kick(ctx, kickvoiceparticipant.Input{ActorID: admin, TargetID: owner})
	if err != nil || result.RevokedLeases != 1 {
		t.Fatalf("kick %v %v", result, err)
	}
	hub := eventhub.New(4)
	target := hub.Subscribe(owner)
	actor := hub.Subscribe(admin)
	outsider := hub.Subscribe(other)
	defer target.Close()
	defer actor.Close()
	defer outsider.Close()
	notify := New(NewRepository(NewPoolDatabase(pool)), testDurableHub{hub})
	if count, err := notify.Dispatch(ctx, 10); err != nil || count != 1 {
		t.Fatalf("dispatch %d %v", count, err)
	}
	select {
	case event := <-target.Events():
		if event.Kind != "voice.lease_revoked" || event.Payload["lease_id"] != lease || event.Payload["reason"] != "KICK" || len(event.Payload) != 2 {
			t.Fatal("wrong targeted contract")
		}
	default:
		t.Fatal("target did not receive event")
	}
	for _, subscriber := range []*eventhub.Subscription{actor, outsider} {
		select {
		case <-subscriber.Events():
			t.Fatal("foreign account received private revocation")
		default:
		}
	}
	result, err = kick.Kick(ctx, kickvoiceparticipant.Input{ActorID: admin, TargetID: owner})
	if err != nil || result.RevokedLeases != 0 {
		t.Fatal("duplicate kick re-revoked lease")
	}
	if count, err := notify.Dispatch(ctx, 10); err != nil || count != 0 {
		t.Fatal("duplicate notification dispatched")
	}
}
