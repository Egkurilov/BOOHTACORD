package pool

import (
	"context"
	"errors"
	"testing"
)

func TestOpenRejectsEmptyDatabaseURL(t *testing.T) {
	_, err := Open(context.Background(), "")
	if !errors.Is(err, ErrDatabaseURLRequired) {
		t.Fatalf("Open() error = %v, want ErrDatabaseURLRequired", err)
	}
}
