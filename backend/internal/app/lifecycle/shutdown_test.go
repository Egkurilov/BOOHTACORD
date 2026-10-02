package lifecycle

import (
	"context"
	"errors"
	"reflect"
	"testing"
)

func TestStartupFailureStillClosesAcquiredResourcesInReverseOrder(t *testing.T) {
	var order []string
	stack := Stack{}
	for _, name := range []string{"telemetry", "database", "worker"} {
		stack.Add(func(context.Context) error { order = append(order, name); return nil })
	}
	if err := stack.Close(t.Context()); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(order, []string{"worker", "database", "telemetry"}) {
		t.Fatal(order)
	}
	if err := stack.Close(t.Context()); err != nil || len(order) != 3 {
		t.Fatal("cleanup repeated")
	}
}

func TestCleanupFailureDoesNotDiscardRemainingResources(t *testing.T) {
	closed := false
	stack := Stack{}
	stack.Add(func(context.Context) error { closed = true; return nil })
	failure := errors.New("worker shutdown")
	stack.Add(func(context.Context) error { return failure })
	if err := stack.Close(t.Context()); !errors.Is(err, failure) || !closed {
		t.Fatal("cleanup lost resources or error")
	}
}

func TestServerStartupFailureReturnsWithoutWaitingForSignal(t *testing.T) {
	failure := errors.New("bind failure")
	if err := Serve(t.Context(), failedServer{failure}); !errors.Is(err, failure) {
		t.Fatalf("got %v", err)
	}
}

type failedServer struct{ err error }

func (s failedServer) ListenAndServe() error        { return s.err }
func (failedServer) Shutdown(context.Context) error { return nil }
func (failedServer) Close() error                   { return nil }
