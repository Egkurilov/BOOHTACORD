package screenpreviewpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Rows interface {
	Next() bool
	Scan(...any) error
	Err() error
	Close()
}
type AudienceDatabase interface {
	Query(context.Context, string, ...any) (Rows, error)
}
type Authorizer struct {
	database Database
	audience AudienceDatabase
}

func New(database Database) Authorizer {
	authorizer := Authorizer{database: database}
	authorizer.audience, _ = database.(AudienceDatabase)
	return authorizer
}

func (authorizer Authorizer) ActiveViewers(ctx context.Context, leaseID string) ([]string, error) {
	if authorizer.audience == nil {
		return nil, screenpreview.ErrUnavailable
	}
	rows, err := authorizer.audience.Query(ctx, activeViewers, leaseID)
	if err != nil {
		return nil, screenpreview.ErrUnavailable
	}
	defer rows.Close()
	accounts := make([]string, 0, 8)
	for rows.Next() {
		var accountID string
		if err := rows.Scan(&accountID); err != nil {
			return nil, screenpreview.ErrUnavailable
		}
		accounts = append(accounts, accountID)
	}
	if rows.Err() != nil {
		return nil, screenpreview.ErrUnavailable
	}
	return accounts, nil
}

func (authorizer Authorizer) AuthorizeUploader(ctx context.Context, principal screenpreview.Principal, leaseID string) (string, error) {
	return authorizer.channel(ctx, uploaderChannel, leaseID, principal.AccountID, principal.SessionDigest[:])
}

func (authorizer Authorizer) AuthorizeViewer(ctx context.Context, principal screenpreview.Principal, leaseID string) (string, error) {
	return authorizer.channel(ctx, viewerChannel, leaseID, principal.AccountID, principal.SessionDigest[:])
}

func (authorizer Authorizer) channel(ctx context.Context, query, leaseID, accountID string, digest []byte) (string, error) {
	var channelID string
	err := authorizer.database.QueryRow(ctx, query, leaseID, accountID, digest).Scan(&channelID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", screenpreview.ErrDenied
	}
	if err != nil {
		return "", fmt.Errorf("authorize private screen preview: %w", screenpreview.ErrUnavailable)
	}
	return channelID, nil
}
