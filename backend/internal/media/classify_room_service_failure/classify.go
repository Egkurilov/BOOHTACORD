package classifyroomservicefailure

import (
	"context"
	"errors"
	"net"
	"net/http"
	"syscall"
)

// Return only bounded classes. Never export dependency text, URL or credentials.
func Classify(response *http.Response, err error) (string, string) {
	if err != nil {
		return transportClass(err), ""
	}
	if response == nil {
		return "other", ""
	}
	status := response.StatusCode
	switch {
	case status == 401:
		return "", "401"
	case status == 403:
		return "", "403"
	case status == 404:
		return "", "404"
	case status >= 500:
		return "", "5xx"
	case status >= 400:
		return "", "other"
	default:
		return "", ""
	}
}

func transportClass(err error) string {
	if errors.Is(err, context.Canceled) {
		return "canceled"
	}
	var timeout net.Error
	if errors.Is(err, context.DeadlineExceeded) || (errors.As(err, &timeout) && timeout.Timeout()) {
		return "timeout"
	}
	var dns *net.DNSError
	if errors.As(err, &dns) {
		return "dns"
	}
	if errors.Is(err, syscall.ECONNRESET) || errors.Is(err, syscall.EPIPE) || errors.Is(err, syscall.Errno(10054)) {
		return "reset"
	}
	var operation *net.OpError
	if errors.As(err, &operation) && operation.Op == "dial" {
		return "connect"
	}
	return "other"
}
