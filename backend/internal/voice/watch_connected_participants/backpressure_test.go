package watchconnectedparticipants

import (
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestBlockedClientWriteHasBoundedDeadline(t *testing.T) {
	finished := make(chan error, 1)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		finished <- writeStreamFrameWithin(writer, writer.(http.Flusher), []byte(strings.Repeat("x", 16<<20)), 40*time.Millisecond)
	}))
	defer server.Close()
	connection, err := net.Dial("tcp", strings.TrimPrefix(server.URL, "http://"))
	if err != nil {
		t.Fatal(err)
	}
	defer connection.Close()
	_, _ = fmt.Fprint(connection, "GET / HTTP/1.1\r\nHost: test\r\n\r\n")
	// Deliberately never read the response; the real socket must time out.
	select {
	case err := <-finished:
		if err == nil {
			t.Fatal("blocked write succeeded without deadline")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("backpressure retained stream handler")
	}
}
