package previewdirectmessageattachment

import (
	"context"

	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
	downloadtext "voice-platform/backend/internal/storage/download_text_attachment"
	previewtext "voice-platform/backend/internal/storage/preview_text_attachment"
)

var ErrPreviewUnavailable = previewtext.ErrPreviewUnavailable

type Downloader interface {
	Open(context.Context, download.Input) (download.Opened, error)
}
type Service struct{ downloader Downloader }

func New(downloader Downloader) Service { return Service{downloader: downloader} }

func (service Service) Render(ctx context.Context, input download.Input) ([]byte, error) {
	return previewtext.New(textAdapter{downloader: service.downloader}).Render(ctx, downloadtext.Input{
		ActorID: input.ActorID, ChannelID: input.DirectMessageID, AttachmentID: input.AttachmentID,
	})
}

type textAdapter struct{ downloader Downloader }

func (adapter textAdapter) Open(ctx context.Context, input downloadtext.Input) (downloadtext.Opened, error) {
	opened, err := adapter.downloader.Open(ctx, download.Input{
		ActorID: input.ActorID, DirectMessageID: input.ChannelID, AttachmentID: input.AttachmentID,
	})
	if err != nil {
		return downloadtext.Opened{}, err
	}
	return downloadtext.Opened{
		Metadata: downloadtext.Metadata{OriginalName: opened.Metadata.OriginalName, StorageKey: opened.Metadata.StorageKey, SizeBytes: opened.Metadata.SizeBytes},
		Reader:   opened.Reader,
	}, nil
}
