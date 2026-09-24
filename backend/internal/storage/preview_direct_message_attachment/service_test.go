package previewdirectmessageattachment

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/jpeg"
	"image/png"
	"io"
	"testing"

	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
)

const (
	actorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	pairID       = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestRenderNormalizesAuthorizedJPEGToPNG(t *testing.T) {
	var source bytes.Buffer
	if err := jpeg.Encode(&source, image.NewRGBA(image.Rect(0, 0, 2, 1)), nil); err != nil {
		t.Fatal(err)
	}
	input := download.Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID}
	downloader := &fakeDownloader{opened: download.Opened{Metadata: download.Metadata{SizeBytes: int64(source.Len())}, Reader: io.NopCloser(bytes.NewReader(source.Bytes()))}}
	rendered, err := New(downloader).Render(context.Background(), input)
	config, decodeErr := png.DecodeConfig(bytes.NewReader(rendered))
	if err != nil || decodeErr != nil || config.Width != 2 || config.Height != 1 || downloader.input != input {
		t.Fatalf("config=%#v renderErr=%v decodeErr=%v input=%#v", config, err, decodeErr, downloader.input)
	}
}

func TestRenderHidesSVG(t *testing.T) {
	source := []byte(`<svg xmlns="http://www.w3.org/2000/svg"><script>x</script></svg>`)
	downloader := &fakeDownloader{opened: download.Opened{Metadata: download.Metadata{SizeBytes: int64(len(source))}, Reader: io.NopCloser(bytes.NewReader(source))}}
	_, err := New(downloader).Render(context.Background(), download.Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID})
	if !errors.Is(err, ErrPreviewUnavailable) {
		t.Fatalf("err=%v", err)
	}
}

func TestRenderPreservesAuthorizationFailure(t *testing.T) {
	_, err := New(&fakeDownloader{err: download.ErrAttachmentUnavailable}).Render(context.Background(), download.Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID})
	if !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("err=%v", err)
	}
}

type fakeDownloader struct {
	input  download.Input
	opened download.Opened
	err    error
}

func (downloader *fakeDownloader) Open(_ context.Context, input download.Input) (download.Opened, error) {
	downloader.input = input
	return downloader.opened, downloader.err
}
