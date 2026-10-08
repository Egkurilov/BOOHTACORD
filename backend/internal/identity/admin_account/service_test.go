package adminaccount

import (
	"context"
	"errors"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"testing"
)

func TestUpdateEmitsSanitizedServerFlowOutcome(t *testing.T) {
	previous := otel.GetTracerProvider()
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	otel.SetTracerProvider(provider)
	t.Cleanup(func() { otel.SetTracerProvider(previous); _ = provider.Shutdown(context.Background()) })
	store := &fakeStore{err: errors.New("private account identifier")}
	_, err := New(store).Update(context.Background(), Input{ActorID: "actor-secret", AccountID: "target-secret", Role: RoleMember, Blocked: true})
	if err == nil {
		t.Fatal("expected update error")
	}
	spans := recorder.Ended()
	if len(spans) != 1 || spans[0].Name() != "admin.account.update.server" || spans[0].Status().Code != codes.Error {
		t.Fatalf("unexpected administrative flow span: %#v", spans)
	}
	for _, attribute := range spans[0].Attributes() {
		if attribute.Value.AsString() == "private account identifier" || attribute.Value.AsString() == "actor-secret" || attribute.Value.AsString() == "target-secret" {
			t.Fatal("administrative flow span contains private account data")
		}
	}
}

func TestUpdatePassesActorTargetRoleAndBlockState(t *testing.T) {
	store := &fakeStore{account: Account{ID: "target", Role: RoleMember, Blocked: true}}
	service := New(store)
	account, err := service.Update(context.Background(), Input{ActorID: "actor", AccountID: "target", Role: RoleMember, Blocked: true})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if store.input.ActorID != "actor" || store.input.AccountID != "target" || account != store.account {
		t.Fatalf("input = %#v, account = %#v", store.input, account)
	}
}

func TestUpdateRejectsUnknownRoleBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	_, err := New(store).Update(context.Background(), Input{ActorID: "actor", AccountID: "target", Role: "OWNER"})
	if !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("Update() error = %v, called = %v", err, store.called)
	}
}

func TestUpdatePreservesLastAdministratorProtection(t *testing.T) {
	store := &fakeStore{err: ErrUpdateDenied}
	_, err := New(store).Update(context.Background(), Input{ActorID: "actor", AccountID: "target", Role: RoleMember, Blocked: true})
	if !errors.Is(err, ErrUpdateDenied) {
		t.Fatalf("Update() error = %v", err)
	}
}

type fakeStore struct {
	input   Input
	account Account
	err     error
	called  bool
}

func (store *fakeStore) Update(_ context.Context, input Input) (Account, error) {
	store.input = input
	store.called = true
	return store.account, store.err
}
