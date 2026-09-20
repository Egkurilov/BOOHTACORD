package previewtextattachment

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"hash/crc32"
	"image"
	"image/png"
	"io"
	"testing"

	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
)

const (
	previewActorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	previewChannelID    = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	previewAttachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestRenderNormalizesAuthorizedRasterToBoundedPNG(t *testing.T) {
	source := rasterFixture(t, 2048, 1024)
	input := downloadtextattachment.Input{ActorID: previewActorID, ChannelID: previewChannelID, AttachmentID: previewAttachmentID}
	downloader := &fakeDownloader{opened: downloadtextattachment.Opened{
		Metadata: downloadtextattachment.Metadata{SizeBytes: int64(len(source))},
		Reader:   io.NopCloser(bytes.NewReader(source)),
	}}
	rendered, err := New(downloader).Render(context.Background(), input)
	config, format, configErr := image.DecodeConfig(bytes.NewReader(rendered))
	if err != nil || configErr != nil || format != "png" || config.Width != 1024 || config.Height != 512 || downloader.input != input {
		t.Fatalf("rendered config = %#v, format = %q, render error = %v, config error = %v, input = %#v", config, format, err, configErr, downloader.input)
	}
}

func TestRenderHidesUnsupportedSourceAsUnavailablePreview(t *testing.T) {
	source := []byte("<svg xmlns=\"http://www.w3.org/2000/svg\"><script>alert(1)</script></svg>")
	downloader := &fakeDownloader{opened: downloadtextattachment.Opened{
		Metadata: downloadtextattachment.Metadata{SizeBytes: int64(len(source))},
		Reader:   io.NopCloser(bytes.NewReader(source)),
	}}
	_, err := New(downloader).Render(context.Background(), downloadtextattachment.Input{ActorID: previewActorID, ChannelID: previewChannelID, AttachmentID: previewAttachmentID})
	if !errors.Is(err, ErrPreviewUnavailable) {
		t.Fatalf("error = %v", err)
	}
}

func TestRenderRejectsRasterHeaderBeyondPixelBoundaryBeforeDecode(t *testing.T) {
	source := pngHeader(4097, 4096)
	downloader := &fakeDownloader{opened: downloadtextattachment.Opened{
		Metadata: downloadtextattachment.Metadata{SizeBytes: int64(len(source))},
		Reader:   io.NopCloser(bytes.NewReader(source)),
	}}
	_, err := New(downloader).Render(context.Background(), downloadtextattachment.Input{ActorID: previewActorID, ChannelID: previewChannelID, AttachmentID: previewAttachmentID})
	if !errors.Is(err, ErrPreviewUnavailable) {
		t.Fatalf("error = %v", err)
	}
}

func rasterFixture(t *testing.T, width, height int) []byte {
	t.Helper()
	image := image.NewNRGBA(image.Rect(0, 0, width, height))
	var buffer bytes.Buffer
	if err := png.Encode(&buffer, image); err != nil {
		t.Fatal(err)
	}
	return buffer.Bytes()
}

func pngHeader(width, height uint32) []byte {
	payload := make([]byte, 13)
	binary.BigEndian.PutUint32(payload, width)
	binary.BigEndian.PutUint32(payload[4:], height)
	payload[8] = 8
	payload[9] = 6
	chunk := append([]byte("IHDR"), payload...)
	buffer := bytes.NewBuffer([]byte{'\x89', 'P', 'N', 'G', '\r', '\n', '\x1a', '\n', 0, 0, 0, 13})
	buffer.Write(chunk)
	checksum := make([]byte, 4)
	binary.BigEndian.PutUint32(checksum, crc32.ChecksumIEEE(chunk))
	buffer.Write(checksum)
	return buffer.Bytes()
}

type fakeDownloader struct {
	input  downloadtextattachment.Input
	opened downloadtextattachment.Opened
	err    error
}

func (downloader *fakeDownloader) Open(_ context.Context, input downloadtextattachment.Input) (downloadtextattachment.Opened, error) {
	downloader.input = input
	return downloader.opened, downloader.err
}
