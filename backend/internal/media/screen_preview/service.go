package screenpreview

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

func New(authority Authority, publications PublicationVerifier, store Store, hints ...HintPublisher) (Service, error) {
	if authority == nil || publications == nil || store == nil {
		return Service{}, ErrUnavailable
	}
	service := Service{authority: authority, publications: publications, store: store}
	if len(hints) > 0 {
		service.hints = hints[0]
	}
	return service, nil
}

func (service Service) Begin(ctx context.Context, principal Principal, leaseID string) (Generation, error) {
	if !validID(leaseID) {
		return Generation{}, ErrInvalidInput
	}
	channelID, err := service.authority.AuthorizeUploader(ctx, principal, leaseID)
	if err != nil {
		return Generation{}, err
	}
	trackSID, err := service.publications.CurrentTrack(ctx, channelID, leaseID)
	if err != nil {
		return Generation{}, publicationError(err)
	}
	generation, err := service.store.Begin(leaseID, trackSID)
	if err != nil {
		return Generation{}, err
	}
	return Generation{SchemaVersion: SchemaVersion, GenerationID: generation, ExpiresAfterSeconds: int(PreviewTTL.Seconds()), MinimumIntervalSeconds: int(UploadInterval.Seconds())}, nil
}

func (service Service) Upload(ctx context.Context, principal Principal, leaseID, generationID string, revision uint64, body []byte) error {
	if !validID(leaseID) || !validID(generationID) || revision == 0 {
		return ErrInvalidInput
	}
	channelID, err := service.authority.AuthorizeUploader(ctx, principal, leaseID)
	if err != nil {
		return err
	}
	trackSID, err := service.store.Reserve(leaseID, generationID, revision)
	if err != nil {
		return err
	}
	currentSID, err := service.publications.CurrentTrack(ctx, channelID, leaseID)
	if err != nil {
		if errors.Is(err, ErrNoPublication) {
			_ = service.store.Invalidate(leaseID, generationID)
			return ErrNotFound
		}
		return ErrUnavailable
	}
	if currentSID != trackSID {
		_ = service.store.Invalidate(leaseID, generationID)
		return ErrStaleGeneration
	}
	if err := ValidateJPEG(body); err != nil {
		return err
	}
	if err := service.store.Commit(leaseID, generationID, revision, body); err != nil {
		return err
	}
	if service.hints != nil {
		service.hints.Updated(ctx, leaseID, generationID, revision)
	}
	return nil
}

func validID(value string) bool { return uuid.Validate(value) == nil }

func publicationError(err error) error {
	if errors.Is(err, ErrNoPublication) {
		return ErrNotFound
	}
	return ErrUnavailable
}
