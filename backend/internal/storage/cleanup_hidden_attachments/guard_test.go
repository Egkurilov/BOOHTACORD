package cleanuphiddenattachments

import (
	"context"
	"errors"
	"testing"
	"time"
)

type blockedGuard struct {
	*fakeStore
	checked bool
}

func (s *blockedGuard) FinalizeWithFile(context.Context, Candidate, func(string) error) error {
	s.checked = true
	return errors.New("new live link")
}

func TestRunChecksGuardBeforeUnlink(t *testing.T) {
	s := &blockedGuard{fakeStore: &fakeStore{items: []Candidate{{ID: "id", Key: "key", Token: "token"}}}}
	f := &fakeFiles{}
	r, err := New(s, f).Run(context.Background(), time.Now(), 1)
	if !errors.Is(err, ErrPartialCleanup) || !s.checked || f.removed != 0 || r.Removed != 0 {
		t.Fatal("A blocked database guard must preserve the file")
	}
}
