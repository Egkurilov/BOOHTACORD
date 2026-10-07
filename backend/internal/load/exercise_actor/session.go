package exercise_actor

import (
	"context"
	"errors"
	"time"
)

func (a *Actor) Start(ctx context.Context) error {
	if err := a.Request(ctx, "login", "POST", "/auth/login", map[string]string{"login": a.Account.Login, "password": a.Account.Password}, 204, nil); err != nil {
		return err
	}
	var session struct {
		ID            string `json:"account_id"`
		Authenticated bool   `json:"authenticated"`
	}
	if err := a.Request(ctx, "session", "GET", "/auth/session", nil, 200, &session); err != nil {
		return err
	}
	if !session.Authenticated || session.ID != a.Account.ID {
		return errors.New("synthetic session owner mismatch")
	}
	if err := a.Read(ctx); err != nil {
		return err
	}
	if err := a.connect(ctx, false); err != nil {
		return err
	}
	var lease struct {
		ID string `json:"id"`
	}
	if err := a.Request(ctx, "lease", "POST", "/voice/channels/"+a.Room+"/leases", map[string]bool{"transfer": false}, 201, &lease); err != nil {
		return err
	}
	if lease.ID == "" {
		return errors.New("empty voice lease")
	}
	a.Lease = lease.ID
	return a.Request(ctx, "credential", "POST", "/voice/leases/"+a.Lease+"/credential", nil, 200, nil)
}
func (a *Actor) Read(ctx context.Context) error {
	for _, op := range []struct{ name, path string }{{"topology", "/channels"}, {"members", "/members?limit=100"}, {"history", "/channels/" + a.Manifest.Text + "/messages?limit=100"}, {"search", "/channels/" + a.Manifest.Text + "/search?query=load&limit=20"}} {
		if err := a.Request(ctx, op.name, "GET", op.path, nil, 200, nil); err != nil {
			return err
		}
	}
	return nil
}
func (a *Actor) Reconnect(ctx context.Context) error {
	started := time.Now()
	if err := a.connect(ctx, true); err != nil {
		a.Results.Observe("reconnect", 503, time.Since(started))
		return err
	}
	if a.Socket.Resync() {
		if err := a.Read(ctx); err != nil {
			return err
		}
	}
	a.Results.Observe("reconnect", 200, time.Since(started))
	return nil
}
func (a *Actor) Stop(ctx context.Context) error {
	a.Socket.Close()
	var first error
	if a.Lease != "" {
		first = a.Request(ctx, "release", "DELETE", "/voice/leases/"+a.Lease, nil, 204, nil)
		a.Lease = ""
	}
	if err := a.Request(ctx, "logout", "POST", "/auth/logout", nil, 204, nil); first == nil {
		first = err
	}
	if err := a.Request(ctx, "revoked", "GET", "/channels", nil, 401, nil); first == nil {
		first = err
	}
	return first
}
