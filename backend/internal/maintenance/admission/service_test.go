package maintenanceadmission

import (
	"context"
	"errors"
	"testing"
)

func TestServiceRejectsOnlyActiveMaintenance(t *testing.T) {
	service := New(&fakeStore{active: true})
	if err := service.RequireOpen(context.Background()); !errors.Is(err, ErrMaintenanceActive) {
		t.Fatalf("RequireOpen() error = %v", err)
	}

	service = New(&fakeStore{})
	if err := service.RequireOpen(context.Background()); err != nil {
		t.Fatalf("RequireOpen() error = %v", err)
	}
}

func TestServiceWritesExplicitMaintenanceState(t *testing.T) {
	store := &fakeStore{}
	if err := New(store).Set(context.Background(), true); err != nil || !store.set || !store.value {
		t.Fatalf("Set() error = %v, store = %#v", err, store)
	}
}

type fakeStore struct {
	active bool
	set    bool
	value  bool
}

func (store fakeStore) Active(context.Context) (bool, error) { return store.active, nil }
func (store *fakeStore) Set(_ context.Context, active bool) error {
	store.set, store.value = true, active
	return nil
}
