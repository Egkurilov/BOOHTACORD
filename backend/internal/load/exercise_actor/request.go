package exercise_actor

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"sync/atomic"
	"time"
	"voice-platform/backend/internal/load/connect_realtime"
	"voice-platform/backend/internal/load/record_results"
	"voice-platform/backend/internal/load/validate_target"
)

type Actor struct {
	Manifest validate_target.Manifest
	Account  validate_target.Account
	Room     string
	Client   *http.Client
	Socket   *connect_realtime.Socket
	Results  *record_results.Results
	Budget   *atomic.Int64
	Lease    string
}

func New(m validate_target.Manifest, index int, r *record_results.Results, budget *atomic.Int64) *Actor {
	return &Actor{Manifest: m, Account: m.Accounts[index], Room: m.Voice[index/20], Client: validate_target.ClientFrom(index + 1), Socket: connect_realtime.New(r), Results: r, Budget: budget}
}
func (a *Actor) Request(ctx context.Context, name, method, path string, body any, expected int, result any) error {
	var reader io.Reader
	content := "application/json"
	if raw, ok := body.(Upload); ok {
		reader = raw.Body
		content = raw.ContentType
	} else if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return errors.New("invalid fixture request")
		}
		reader = bytes.NewReader(data)
	}
	if a.Budget.Add(1) > int64(a.Manifest.MaxRequests) && name != "release" && name != "logout" && name != "revoked" {
		return errors.New("request budget exhausted")
	}
	req, err := http.NewRequestWithContext(ctx, method, a.Manifest.Origin+"/api/v1"+path, reader)
	if err != nil {
		return errors.New("invalid request")
	}
	req.Header.Set("Origin", a.Manifest.Origin)
	if name == "origin_acl" {
		req.Header.Set("Origin", "https://foreign.invalid")
	}
	req.Header.Set("Content-Type", content)
	started := time.Now()
	response, err := a.Client.Do(req)
	if err != nil {
		a.Results.Observe(name, 503, time.Since(started))
		return errors.New("request transport failed")
	}
	defer response.Body.Close()
	status := response.StatusCode
	a.Results.ObserveOutcome(name, status, time.Since(started), status == expected)
	if status != expected {
		return errors.New("unexpected " + name + " response status")
	}
	if result == nil {
		_, err = io.Copy(io.Discard, io.LimitReader(response.Body, 1<<20))
		return err
	}
	if sink, ok := result.(io.Writer); ok {
		_, err = io.Copy(sink, io.LimitReader(response.Body, 25000001))
		return err
	}
	if json.NewDecoder(io.LimitReader(response.Body, 1<<20)).Decode(result) != nil {
		return errors.New("invalid " + name + " response")
	}
	return nil
}

type Upload struct {
	Body        io.Reader
	ContentType string
}
