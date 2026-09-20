package maintenanceadmission

import (
	"context"
	"errors"
	"fmt"
)

var ErrMaintenanceActive = errors.New("maintenance admission is active")

type Store interface {
	Active(context.Context) (bool, error)
	Set(context.Context, bool) error
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) RequireOpen(context context.Context) error {
	active, err := service.store.Active(context)
	if err != nil {
		return fmt.Errorf("read maintenance admission: %w", err)
	}
	if active {
		return ErrMaintenanceActive
	}
	return nil
}

func (service Service) Active(context context.Context) (bool, error) {
	active, err := service.store.Active(context)
	if err != nil {
		return false, fmt.Errorf("read maintenance admission: %w", err)
	}
	return active, nil
}

func (service Service) Set(context context.Context, active bool) error {
	if err := service.store.Set(context, active); err != nil {
		return fmt.Errorf("set maintenance admission: %w", err)
	}
	return nil
}
