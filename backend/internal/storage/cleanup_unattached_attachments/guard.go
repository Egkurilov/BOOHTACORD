package cleanupunattachedattachments

import "context"

type guardedStore interface {
	FinalizeWithFile(context.Context, Candidate, func(string) error) error
}

func (service Service) finalize(ctx context.Context, candidate Candidate) error {
	if guarded, ok := service.store.(guardedStore); ok {
		return guarded.FinalizeWithFile(ctx, candidate, service.files.Remove)
	}
	if err := service.files.Remove(candidate.Key); err != nil {
		return err
	}
	return service.store.Finalize(ctx, candidate.ID)
}
