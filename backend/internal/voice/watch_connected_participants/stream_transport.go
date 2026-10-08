package watchconnectedparticipants

import (
	"errors"
	"net/http"
	"time"
)

const streamWriteTimeout = 3 * time.Second

func writeStreamFrame(writer http.ResponseWriter, flusher http.Flusher, frame []byte) error {
	return writeStreamFrameWithin(writer, flusher, frame, streamWriteTimeout)
}

func writeStreamFrameWithin(writer http.ResponseWriter, flusher http.Flusher, frame []byte, timeout time.Duration) error {
	controller := http.NewResponseController(writer)
	// net/http bounds a client that stops reading; test recorders can lack this.
	if err := controller.SetWriteDeadline(time.Now().Add(timeout)); err != nil && !errors.Is(err, http.ErrNotSupported) {
		return err
	}
	defer controller.SetWriteDeadline(time.Time{})
	if _, err := writer.Write(frame); err != nil {
		return err
	}
	if err := controller.Flush(); errors.Is(err, http.ErrNotSupported) {
		flusher.Flush()
		return nil
	} else {
		return err
	}
}
