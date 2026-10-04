package welcomepostgres

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"io"
	"time"
	guildsettingspostgres "voice-platform/backend/internal/guild/update_settings/postgres"
	registeruser "voice-platform/backend/internal/identity/register_user"
	registerpostgres "voice-platform/backend/internal/identity/register_user/postgres"
	registrationwelcome "voice-platform/backend/internal/identity/registration_welcome"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Database interface {
	Begin(context.Context) (pgx.Tx, error)
}
type Publisher interface {
	PublishContext(context.Context, eventhub.Event) error
}
type Repository struct {
	Database Database
	Observer *guildlifecycle.Observer
	Events   Publisher
	Random   io.Reader
}

func (r Repository) Create(ctx context.Context, account registeruser.Account) error {
	tx, err := r.Database.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	if _, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock($1)", guildsettingspostgres.TopologyLock); err != nil {
		return err
	}
	if err = registerpostgres.New(tx).Create(ctx, account); err != nil {
		return err
	}
	ctx, span := r.Observer.StartWelcome(ctx)
	details := guildlifecycle.Details{UserID: account.ID, UserName: account.DisplayName, FailureStage: "database"}
	var channel *string
	if err = tx.QueryRow(ctx, `SELECT welcome_channel_id::text FROM guild_settings WHERE singleton=TRUE FOR UPDATE`).Scan(&channel); err != nil {
		span.Fail(err, details)
		return err
	}
	outcome := "skipped_disabled"
	if channel != nil {
		details.Enabled, details.ChannelID = true, *channel
		var active bool
		// The share lock also protects against channel changes outside the topology API.
		err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM (SELECT id FROM channels WHERE id=$1::uuid AND kind='TEXT' AND archived_at IS NULL FOR SHARE) AS active)`, *channel).Scan(&active)
		if err != nil {
			span.Fail(err, details)
			return err
		}
		if !active {
			outcome = "skipped_channel_unavailable"
			if err = clearUnavailable(ctx, tx, account.ID); err != nil {
				span.Fail(err, details)
				return err
			}
		} else {
			var phrase registrationwelcome.Phrase
			details.FailureStage = "phrase_selection"
			phrase, err = registrationwelcome.SelectPhrase(r.Random)
			if err != nil {
				span.Fail(err, details)
				return err
			}
			details.FailureStage = "database"
			details.MessageID, details.PhraseID = uuid.NewString(), phrase.ID
			if err = insertWelcome(ctx, tx, account.ID, details.ChannelID, details.MessageID, phrase); err != nil {
				span.Fail(err, details)
				return err
			}
			outcome = "published"
		}
	}
	if err = tx.Commit(ctx); err != nil {
		span.Fail(err, details)
		return err
	}
	details.Committed, details.FailureStage = true, ""
	// Persisted history is authoritative; a hint failure cannot undo registration.
	if outcome == "published" {
		publishCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
		defer cancel()
		if r.Events == nil {
			err = eventhub.ErrJournalUnavailable
		} else {
			err = r.Events.PublishContext(publishCtx, eventhub.Event{EventID: uuid.NewString(), Kind: "message.created", OccurredAt: time.Now().UTC(), Payload: map[string]any{"channel_id": details.ChannelID, "message_id": details.MessageID}})
		}
		if err != nil {
			details.FailureStage = "realtime"
			span.Fail(err, details)
			return nil
		}
	}
	span.Finish(outcome, details)
	return nil
}
