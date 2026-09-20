package writeupload

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestWriteGuardedRemovesTemporaryFileAfterGuardFailure(t *testing.T) {
	directory := t.TempDir()
	writer, err := New(directory)
	if err != nil {
		t.Fatal(err)
	}
	errNoCapacity := errors.New("no capacity")
	guardCalls := 0
	_, err = writer.WriteGuarded(context.Background(), strings.NewReader("bytes"), func(context.Context) error {
		guardCalls++
		return errNoCapacity
	})
	if !errors.Is(err, errNoCapacity) || guardCalls != 1 {
		t.Fatalf("guard calls = %d, error = %v", guardCalls, err)
	}
	assertDirectoryEmpty(t, directory)
}
