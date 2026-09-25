package downloaddirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
	downloadtext "voice-platform/backend/internal/storage/download_text_attachment"
	preview "voice-platform/backend/internal/storage/preview_direct_message_attachment"
)

func TestPrivateDMHTMLAndSVGFilesCannotBePreviewed(t *testing.T) {
	for _, file := range []struct{ name, body string }{
		{"private.html", "<html><script>x</script></html>"},
		{"private.svg", `<svg xmlns="http://www.w3.org/2000/svg"><script>x</script></svg>`},
	} {
		t.Run(file.name, func(t *testing.T) {
			fixture := newAttachmentFixture(t)
			ctx := context.Background()
			directory := t.TempDir()
			if err := os.WriteFile(filepath.Join(directory, fixture.storageKey), []byte(file.body), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := fixture.pool.Exec(ctx, `UPDATE attachments SET original_name=$2,byte_size=$3 WHERE id=$1`, fixture.attached, file.name, len(file.body)); err != nil {
				t.Fatal(err)
			}
			files, err := downloadtext.NewFileStore(directory)
			if err != nil {
				t.Fatal(err)
			}
			viewer := preview.New(download.New(New(NewPoolDatabase(fixture.pool)), files))
			_, err = viewer.Render(ctx, download.Input{ActorID: fixture.actor, DirectMessageID: fixture.pair, AttachmentID: fixture.attached})
			if !errors.Is(err, preview.ErrPreviewUnavailable) {
				t.Fatalf("preview error=%v", err)
			}
		})
	}
}
