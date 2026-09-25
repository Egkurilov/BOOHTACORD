package downloaddirectmessageattachmentpostgres

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"testing"

	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
	downloadtext "voice-platform/backend/internal/storage/download_text_attachment"
	preview "voice-platform/backend/internal/storage/preview_direct_message_attachment"
)

func TestPrivateDMFileAndPreviewRequireLiveParticipantLink(t *testing.T) {
	fixture := newAttachmentFixture(t)
	ctx := context.Background()
	var encoded bytes.Buffer
	if err := png.Encode(&encoded, image.NewRGBA(image.Rect(0, 0, 2, 1))); err != nil {
		t.Fatal(err)
	}
	directory := t.TempDir()
	if err := os.WriteFile(filepath.Join(directory, fixture.storageKey), encoded.Bytes(), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.pool.Exec(ctx, `UPDATE attachments SET original_name='private.png',byte_size=$2 WHERE id=$1`, fixture.attached, encoded.Len()); err != nil {
		t.Fatal(err)
	}
	files, err := downloadtext.NewFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	downloader := download.New(New(NewPoolDatabase(fixture.pool)), files)
	viewer := preview.New(downloader)
	for _, actor := range []string{fixture.actor, fixture.peer} {
		input := download.Input{ActorID: actor, DirectMessageID: fixture.pair, AttachmentID: fixture.attached}
		opened, err := downloader.Open(ctx, input)
		if err != nil {
			t.Fatal(err)
		}
		body, readErr := io.ReadAll(opened.Reader)
		_ = opened.Reader.Close()
		if readErr != nil || !bytes.Equal(body, encoded.Bytes()) {
			t.Fatalf("participant download failed: %v", readErr)
		}
		rendered, err := viewer.Render(ctx, input)
		if err != nil || !bytes.Equal(rendered, encoded.Bytes()) {
			t.Fatalf("participant preview failed: %v", err)
		}
	}
	for _, denied := range []download.Input{
		{ActorID: fixture.outsider, DirectMessageID: fixture.pair, AttachmentID: fixture.attached},
		{ActorID: fixture.actor, DirectMessageID: fixture.otherPair, AttachmentID: fixture.attached},
	} {
		if _, err := downloader.Open(ctx, denied); !errors.Is(err, download.ErrAttachmentUnavailable) {
			t.Fatalf("download ACL error=%v", err)
		}
		if _, err := viewer.Render(ctx, denied); !errors.Is(err, download.ErrAttachmentUnavailable) {
			t.Fatalf("preview ACL error=%v", err)
		}
	}
	if _, err := fixture.pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, fixture.peer); err != nil {
		t.Fatal(err)
	}
	blocked := download.Input{ActorID: fixture.peer, DirectMessageID: fixture.pair, AttachmentID: fixture.attached}
	if _, err := downloader.Open(ctx, blocked); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("blocked download error=%v", err)
	}
	if _, err := viewer.Render(ctx, blocked); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("blocked preview error=%v", err)
	}
	if _, err := fixture.pool.Exec(ctx, `UPDATE direct_message_messages SET body='',deleted_at=now() WHERE id=$1`, fixture.message); err != nil {
		t.Fatal(err)
	}
	input := download.Input{ActorID: fixture.actor, DirectMessageID: fixture.pair, AttachmentID: fixture.attached}
	if _, err := downloader.Open(ctx, input); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("deleted download error=%v", err)
	}
	if _, err := viewer.Render(ctx, input); !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("deleted preview error=%v", err)
	}
	if _, err := os.Stat(filepath.Join(directory, fixture.storageKey)); err != nil {
		t.Fatalf("test file unexpectedly absent: %v", err)
	}
}
