package previewtextattachment

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"io"

	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
)

const (
	MaxPreviewDimension = 1024
	MaxSourcePixels     = 16_777_216
)

var ErrPreviewUnavailable = errors.New("text attachment preview unavailable")

type Downloader interface {
	Open(context.Context, downloadtextattachment.Input) (downloadtextattachment.Opened, error)
}

type Service struct{ downloader Downloader }

func New(downloader Downloader) Service { return Service{downloader: downloader} }

func (service Service) Render(ctx context.Context, input downloadtextattachment.Input) ([]byte, error) {
	opened, err := service.downloader.Open(ctx, input)
	if err != nil {
		return nil, err
	}
	defer opened.Reader.Close()
	source, err := io.ReadAll(io.LimitReader(opened.Reader, downloadtextattachment.MaxAttachmentBytes+1))
	if err != nil {
		return nil, fmt.Errorf("read authorized attachment preview: %w", err)
	}
	if int64(len(source)) != opened.Metadata.SizeBytes || len(source) > int(downloadtextattachment.MaxAttachmentBytes) {
		return nil, ErrPreviewUnavailable
	}
	config, format, err := image.DecodeConfig(bytes.NewReader(source))
	if err != nil || !supportedFormat(format) || !validConfig(config) {
		return nil, ErrPreviewUnavailable
	}
	decoded, format, err := image.Decode(bytes.NewReader(source))
	if err != nil || !supportedFormat(format) || !sameDimensions(decoded.Bounds(), config) {
		return nil, ErrPreviewUnavailable
	}
	preview := scale(decoded, previewDimensions(config))
	var rendered bytes.Buffer
	if err := png.Encode(&rendered, preview); err != nil {
		return nil, fmt.Errorf("encode normalized attachment preview: %w", err)
	}
	return rendered.Bytes(), nil
}

func supportedFormat(format string) bool {
	return format == "png" || format == "jpeg" || format == "gif"
}

func validConfig(config image.Config) bool {
	return config.Width > 0 && config.Height > 0 && config.Width <= MaxSourcePixels/config.Height
}

func sameDimensions(bounds image.Rectangle, config image.Config) bool {
	return bounds.Dx() == config.Width && bounds.Dy() == config.Height
}

func previewDimensions(config image.Config) image.Point {
	longest := max(config.Width, config.Height)
	if longest <= MaxPreviewDimension {
		return image.Pt(config.Width, config.Height)
	}
	return image.Pt(
		(config.Width*MaxPreviewDimension+longest-1)/longest,
		(config.Height*MaxPreviewDimension+longest-1)/longest,
	)
}

func scale(source image.Image, dimensions image.Point) *image.NRGBA {
	bounds := source.Bounds()
	preview := image.NewNRGBA(image.Rect(0, 0, dimensions.X, dimensions.Y))
	for y := 0; y < dimensions.Y; y++ {
		sourceY := bounds.Min.Y + y*bounds.Dy()/dimensions.Y
		for x := 0; x < dimensions.X; x++ {
			sourceX := bounds.Min.X + x*bounds.Dx()/dimensions.X
			preview.Set(x, y, source.At(sourceX, sourceY))
		}
	}
	return preview
}
