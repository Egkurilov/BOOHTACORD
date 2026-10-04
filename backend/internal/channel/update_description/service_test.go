package updatedescription

import (
	"context"
	"errors"
	"strings"
	"testing"
)

type storeFunc func(context.Context, Input) (Result, error)

func (f storeFunc) Update(ctx context.Context, input Input) (Result, error) { return f(ctx, input) }

func TestUpdateAllowsEmptyDescriptionAndRejectsInvalidInput(t *testing.T) {
	called := false
	service := New(storeFunc(func(_ context.Context, input Input) (Result, error) {
		called = true
		return Result{ID: input.ChannelID, Description: input.Description, Revision: 3}, nil
	}))
	result, err := service.Update(context.Background(), Input{ActorID: "admin", ChannelID: "channel", ExpectedRevision: 2})
	if err != nil || result.Description != "" || !called {
		t.Fatalf("result=%#v err=%v called=%v", result, err, called)
	}
	for _, input := range []Input{
		{ChannelID: "channel", ExpectedRevision: 2},
		{ActorID: "admin", ExpectedRevision: 2},
		{ActorID: "admin", ChannelID: "channel"},
		{ActorID: "admin", ChannelID: "channel", ExpectedRevision: 2, Description: strings.Repeat("a", 201)},
	} {
		called = false
		_, err := service.Update(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || called {
			t.Fatalf("input=%#v err=%v called=%v", input, err, called)
		}
	}
}
