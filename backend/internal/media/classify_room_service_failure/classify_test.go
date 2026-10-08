package classifyroomservicefailure

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"syscall"
	"testing"
)

func TestTransportFailuresUseFixedClassesWithoutDependencyText(t *testing.T) {
	for _, test := range []struct {
		err   error
		class string
	}{
		{fmt.Errorf("private request: %w", context.Canceled), "canceled"},
		{context.DeadlineExceeded, "timeout"},
		{&net.DNSError{Name: "secret.host", Err: "private lookup"}, "dns"},
		{&net.OpError{Op: "dial", Err: syscall.ECONNREFUSED}, "connect"},
		{&net.OpError{Op: "read", Err: syscall.ECONNRESET}, "reset"},
		{syscall.Errno(10054), "reset"},
		{errors.New("private URL token"), "other"},
	} {
		transport, status := Classify(nil, test.err)
		if transport != test.class || status != "" {
			t.Fatalf("class=%q status=%q wanted=%s", transport, status, test.class)
		}
	}
}

func TestHTTPFailuresUseStatusFamilyAndSuccessIsNotFailure(t *testing.T) {
	for _, test := range []struct {
		status int
		class  string
	}{{200, ""}, {401, "401"}, {403, "403"}, {404, "404"}, {429, "other"}, {503, "5xx"}, {599, "5xx"}} {
		transport, status := Classify(&http.Response{StatusCode: test.status}, nil)
		if transport != "" || status != test.class {
			t.Fatalf("status=%d class=%s transport=%s", test.status, status, transport)
		}
	}
}
