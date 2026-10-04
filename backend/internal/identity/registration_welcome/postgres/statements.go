package welcomepostgres

import (
	"context"
	"github.com/jackc/pgx/v5"
	registrationwelcome "voice-platform/backend/internal/identity/registration_welcome"
)

func insertWelcome(ctx context.Context, tx pgx.Tx, account, channel, message string, phrase registrationwelcome.Phrase) error {
	_, err := tx.Exec(ctx, `INSERT INTO messages(id,channel_id,author_id,client_message_id,body,kind,mention_user_ids)
 VALUES($1::uuid,$2::uuid,$3::uuid,$1::uuid,$4,'SYSTEM_WELCOME',ARRAY[$3::uuid])`, message, channel, account, phrase.Body)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `INSERT INTO audit_events(actor_user_id,event_type,target_user_id,metadata)
 VALUES($1::uuid,'REGISTRATION_WELCOME_PUBLISHED',$1::uuid,
 jsonb_build_object('channel_id',$2::text,'message_id',$3::text,'phrase_id',$4::text))`, account, channel, message, phrase.ID)
	return err
}
func clearUnavailable(ctx context.Context, tx pgx.Tx, actor string) error {
	_, err := tx.Exec(ctx, `WITH changed AS (
 UPDATE guild_settings SET welcome_channel_id=NULL,revision=revision+1,updated_at=now()
 WHERE singleton=TRUE RETURNING revision
 ) INSERT INTO audit_events(actor_user_id,event_type,metadata)
 SELECT $1::uuid,'GUILD_WELCOME_SETTINGS_UPDATED',jsonb_build_object('revision',revision,
 'changed_fields',jsonb_build_array('welcome_channel_id'),'reason','channel_unavailable') FROM changed`, actor)
	return err
}
