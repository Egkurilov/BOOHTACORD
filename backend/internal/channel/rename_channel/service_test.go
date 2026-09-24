package renamechannel

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestRenamePassesChannelNameAndExpectedRevision(t *testing.T) {
	store := &fakeStore{result: Result{ID: "channel-1", Name: "Игры", Revision: 3}}
	input := Input{ActorID: "admin-1", ChannelID: "channel-1", Name: "Игры", ExpectedRevision: 2}
	result, err := New(store).Rename(context.Background(), input)
	if err != nil || store.input != input || result != store.result {
		t.Fatalf("result = %#v, input = %#v, error = %v", result, store.input, err)
	}
}

func TestRenameRejectsInvalidInputBeforeStore(t *testing.T) {
	valid := Input{ActorID: "admin-1", ChannelID: "channel-1", Name: "Игры", ExpectedRevision: 2}
	tests := []struct {
		name  string
		input Input
	}{
		{"actor", Input{ChannelID: valid.ChannelID, Name: valid.Name, ExpectedRevision: valid.ExpectedRevision}},
		{"channel", Input{ActorID: valid.ActorID, Name: valid.Name, ExpectedRevision: valid.ExpectedRevision}},
		{"revision", Input{ActorID: valid.ActorID, ChannelID: valid.ChannelID, Name: valid.Name}},
		{"empty name", Input{ActorID: valid.ActorID, ChannelID: valid.ChannelID, ExpectedRevision: valid.ExpectedRevision}},
		{"long name", Input{ActorID: valid.ActorID, ChannelID: valid.ChannelID, Name: strings.Repeat("я", 81), ExpectedRevision: valid.ExpectedRevision}},
		{"invalid utf8", Input{ActorID: valid.ActorID, ChannelID: valid.ChannelID, Name: string([]byte{0xff}), ExpectedRevision: valid.ExpectedRevision}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			store := &fakeStore{}
			_, err := New(store).Rename(context.Background(), test.input)
			if !errors.Is(err, ErrInvalidInput) || store.called {
				t.Fatalf("error = %v, store called = %v", err, store.called)
			}
		})
	}
}

func TestRenamePreservesRevisionConflict(t *testing.T) {
	store := &fakeStore{err: ErrRevisionConflict}
	_, err := New(store).Rename(context.Background(), Input{ActorID: "admin-1", ChannelID: "channel-1", Name: "Игры", ExpectedRevision: 2})
	if !errors.Is(err, ErrRevisionConflict) {
		t.Fatalf("error = %v", err)
	}
}

type fakeStore struct {
	input  Input
	result Result
	err    error
	called bool
}

func (store *fakeStore) Rename(_ context.Context, input Input) (Result, error) {
	store.input, store.called = input, true
	return store.result, store.err
}
