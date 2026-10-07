package exercise_actor

import (
	"context"
	"errors"
	"voice-platform/backend/internal/load/validate_target"
)

// ADR-003: ten attempts per five minutes per source IP. This independent profile
// uses one source; the normal 100-source profile does not bypass this quota.
func (a *Actor) SharedNAT(ctx context.Context) error {
	a.Client = validate_target.ClientFrom(199)
	for attempt := 0; attempt < 11; attempt++ {
		expected, name := 204, "login"
		if attempt == 10 {
			expected, name = 429, "nat_limit"
		}
		var result any
		var denied struct {
			Error struct {
				Code string `json:"code"`
			} `json:"error"`
		}
		if expected == 429 {
			result = &denied
		}
		if err := a.Request(ctx, name, "POST", "/auth/login", map[string]string{"login": a.Account.Login, "password": a.Account.Password}, expected, result); err != nil {
			return err
		}
		if expected == 429 {
			if denied.Error.Code != "RATE_LIMITED" {
				return errors.New("unexpected shared-source quota response")
			}
			return nil
		}
		if err := a.Request(ctx, "logout", "POST", "/auth/logout", nil, 204, nil); err != nil {
			return err
		}
	}
	return nil
}
